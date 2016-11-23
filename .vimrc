augroup moonmoon_moonscript
	autocmd BufWritePost *.moon AsyncRun ./compile.sh
	autocmd BufWritePost *.ld AsyncRun ./compile.sh
augroup END

setlocal suffixesadd+=.moon
