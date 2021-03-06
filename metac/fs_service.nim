# included from metac/fs.nim

proc main*() {.async.} =
  let instance = await newServiceInstance("fs")

  let rootNamespace = LocalNamespace(instance: instance).asFilesystemNamespace

  let serviceAdmin = inlineCap(FilesystemServiceAdmin, FilesystemServiceAdminInlineImpl(
    rootNamespace: (() => now(just(rootNamespace)))
  ))

  await instance.registerRestorer(
    proc(d: CapDescription): Future[AnyPointer] =
      case d.category:
      of "fs:localfile":
        return localFilePersistable(instance, d.description.castAs(string), runtimeId=d.runtimeId).toAnyPointer.just
      of "fs:localfs":
        return localFsPersistable(instance, d.description.castAs(string)).toAnyPointer.just
      of "fs:mount":
        let params = d.description.castAs(FilesystemNamespace_mount_Params)
        return rootNamespace.mount(params.path, params.fs).toAnyPointerFuture
      else:
        return error(AnyPointer, "unknown category " & d.category))

  await instance.runService(
    service=Service.createFromCap(nothingImplemented),
    adminBootstrap=ServiceAdmin.createFromCap(serviceAdmin.toCapServer)
  )

when isMainModule:
  disableFdInheritance()
  main().runMain
