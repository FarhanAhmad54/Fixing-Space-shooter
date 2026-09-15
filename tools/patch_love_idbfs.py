import os

target = 'Module.addRunDependency("IDBFS_sync");FS.mkdir("/home/web_user/love");FS.mount(IDBFS,{},"/home/web_user/love");FS.syncfs(true,function(err){if(err){Module["printErr"](err)}else{Module.removeRunDependency("IDBFS_sync")}});window.addEventListener("beforeunload",function(event){FS.syncfs(false,function(err){if(err){Module["printErr"](err)}})})'
replacement = 'Module.addRunDependency("IDBFS_sync");try{FS.mkdir("/home/web_user/love");FS.mount(IDBFS,{},"/home/web_user/love");FS.syncfs(true,function(err){if(err){Module["printErr"]("IDBFS syncfs warning: "+err)}Module.removeRunDependency("IDBFS_sync")});window.addEventListener("beforeunload",function(event){try{FS.syncfs(false,function(err){if(err){Module["printErr"](err)}})}catch(e){}})}catch(e){Module["printErr"]("IDBFS mount error: "+e);Module.removeRunDependency("IDBFS_sync")}'

for p in ['tools/.lovejs_cache/love.js', 'web/dist_poki/love.js']:
    if os.path.exists(p):
        content = open(p, 'r', encoding='utf-8').read()
        if target in content:
            open(p, 'w', encoding='utf-8').write(content.replace(target, replacement))
            print('Successfully patched', p)
        elif 'IDBFS mount error' in content:
            print('Already patched', p)
        else:
            print('Target not found in', p)
