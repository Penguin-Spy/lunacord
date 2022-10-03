# windows install instructions
> I LOVE WINDOWS ITS SO COOL AND GOOD AND NOT ANNOYING TO USE :)))))

install MSYS2
install luarocks
install openssl (using msys2, read NOTES_WINDOWS.md)
add `C:\msys64\usr\local\bin` to ur path & copy+rename the `-3-x64.dll`s to `libssl.dll` and `libcrypto.dll`
install lua-websockets using the scm-1 rockspec on the github repo
- make sure to edit out the dependency on `luabitop`, `lua-ev`, and `copas`
- `luarocks install bit32`
