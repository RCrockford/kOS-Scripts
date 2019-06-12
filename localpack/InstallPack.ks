@lazyglobal off.

// List of paths without volume.
parameter fileList.

switch to 0.

//for f in fileList
//{
//    local ksmPath is f:ChangeExtension("ksm").
//   
//    compile f to ksmPath.
//    
//    if Open(ksmPath):ReadAll:Length < Open(f):ReadAll:Length
//        set f to ksmPath.
//}

switch to 1.

local archRoot is path("0:/").
for f in fileList
{
    copypath(archRoot:Combine(f), f).
}
