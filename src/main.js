const fs = require('fs/promises');
const path = require('path')

const cds = require('@sap/cds')

const src = fs.readFile(path.resolve(__dirname, 'main.wasm'))

cds.on('served', async () => {
  let mem, instance
  const get = function (ptr, length) {
    return Buffer.from(mem.buffer.slice(ptr, ptr + length)) + ''
  }

  const set = function (data) {
    if (!Buffer.isBuffer(data)) {
      if (typeof data === 'object') data = Buffer.from(JSON.stringify(data))
      else data = Buffer.from(data)
    }
    const ptr = instance.exports.alloc(data.length)
    const raw = new Uint8Array(mem.buffer)
    data.copy(raw, ptr)
    return { ptr, length: data.length }
  }

  let proms
  let ret
  const track = async function (cb) {
    proms = []
    ret = undefined
    cb()
    await Promise.all(proms).then(() => { })
    return ret
  }

  const tracked = function (cb) {
    return function () {
      const ret = cb.apply(null, arguments)
      if (proms)
        proms.push(ret)
    }
  }

  const cdsService = async function (ptr, length) {
    const opts = JSON.parse(get(ptr, length))
    const srv = await cds.connect.to(opts.service)
    srv[opts.hook](opts.event, opts.entity, async (req) => {
      const ptr = set({
        data: req.data || {},
        locale: req.locale || null,
        tenant: req.tenant || null,
        user: {
          id: req.user.id,
          roles: req.user.roles,
        },
        target: req?.target?.name || null,
      })
      return track(() => instance.exports[opts.cb](ptr.ptr, ptr.length))
    })
  }

  const cdsSelect = async function (ptr, length) {
    const cqn = JSON.parse(get(ptr, length))
    const q = cds.ql.SELECT()
    if (cqn.one) q.SELECT.one = cqn.one
    if (cqn.from) q.from(cqn.from)
    if (cqn.columns) q.columns(cqn.columns)
    const res = await q
    ptr = set(res)
    return track(() => { instance.exports[cqn.cb](ptr.ptr, ptr.length) })
  }

  const cdsContext = async function (ptr, length) {
    const cqn = JSON.parse(get(ptr, length))
    cds.context.data[cqn.key] = cqn.value
  }

  const cdsReturn = function (ptr, length) {
    ret = JSON.parse(get(ptr, length))
  }

  const cdsReturnAsync = function () {
    ret = proms.at(-1)
  }

  WebAssembly.instantiate(new Uint8Array(await src), {
    env: {
      CDS_RETURN: cdsReturn,
      CDS_RETURN_ASYNC: cdsReturnAsync,
      CDS_CONTEXT: tracked(cdsContext),
      CDS_SERVICE: tracked(cdsService),
      CDS_SELECT: tracked(cdsSelect),
      print: (ptr, length) => { console.log(get(ptr, length)); }
    }
  }).then(result => {
    instance = result.instance;
    mem = result.instance.exports.memory;
    result.instance.exports.main();
  });

})
