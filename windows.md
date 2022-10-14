# windows install instructions
> I LOVE WINDOWS ITS SO COOL AND GOOD AND NOT ANNOYING TO USE :)))))

install MSYS2
install luarocks
- configure it to use the msys compiler
```lua
external_deps_dirs = {
  "c:/windows/system32/",
  -- ensure the following lines are here. leave anything that's already there (like system32)
  "c:/msys64/usr",
  "c:/msys64/usr/local",
  "c:/msys64/usr/local/lib64"
}

variables = {
  CC = "x86_64-w64-mingw32-gcc",
  LD = "x86_64-w64-mingw32-gcc",
  -- probably also need this due to a bug
  MD5SUM = "md5sum",
}
```

install openssl (using msys2, read NOTES_WINDOWS.md)
add `C:\msys64\usr\local\bin` to ur path & copy+rename the `-3-x64.dll`s in there to `libssl.dll` and `libcrypto.dll`
install lua-websockets as per this project's readme
