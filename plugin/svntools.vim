" Adds some cooperation with SVN working copies to vim.
" Introduces the idea of 'SVN Mode' - once an SVN tab is opened by one of the commands, that tab is in SVN Mode for that file or dir. Executing another such command in that tab will act as if executed in the tab for that file or dir. Handy for jumping back and forth between svn log, revision diffs, etc.
" 	For example: execute :Slog, which opens a tab containing the log for that file. Put cursor over a revision number in the log, hit \sr. Diff of that revision will appear in the same tab. Execute :Slog again to return to the log.
" Commands and shortcuts:
" :Sdiff [path [changelist]] - show svn diff of current file or path using optional changelist
" :Slog [path] - show svn log of current file or path
" :Sinfo [path] - show svn info of current file or path
" :Sblame - show svn blame of current file
" :Sdiffs [rev] - do a diffsplit of current file with version at revision (default HEAD) (very handy for refactoring)
" :Swin <path> - create a new SVN window for path
" :Srev <rev[:rev]> - view diff for revision(s)
" \sr - show diff for file for revision under cursor.
" 	For example, execute :Slog for a file, put cursor over 'r1234' in the log, and hit \sr
" \sf - view file under cursor at revision in diff
"		For example, put cursor over the following line in a diff: "+++ path/to/some/class.php (revision 1234)"
" Known issues:
" - If an SVNMode window is the only open tab, executing any SVNMode command closes vim
" - Using \sf in an SVNMode window for a file breaks; only works in a SVNMode window for a dir
let g:svn_diff_opt = "-w"
"let g:svn_diff_opt = "--ignore-eol-style"
com! -nargs=? Sdiff :call SvnDiff("<args>",bufname('%'))
com! -nargs=? Slog :call SvnLog("<args>",bufname('%'))
com! -nargs=? Sinfo :call SvnInfo("<args>",bufname('%'))
com! -nargs=0 -range Scdiff :call SvnConflictDiff(<count>)
com! Sblame :call SvnBlame(bufname('%'))
com! -nargs=? Sdiffs :call SvnDiffSplit(expand('%:h'),expand('%:t'),"<args>")
com! -nargs=? Srev :call SvnModeDiff("<args>")
com! -nargs=? Swin :call SvnModeWindow("<args>")
com! -nargs=? Scl :call SvnChangeList("<args>",bufname('%'))
com! -nargs=0 Sclr :exe "!svn cl --remove ".bufname('%')
" view diff for file at revision under cursor
nmap <Leader>sr :call SvnModeDiff(expand('<cword>'))<CR>gg
nmap <Leader>sf :call SvnModeExport()<CR>gg
nmap <Leader>sa :call SvnAdd(bufname('%'))<CR>
nmap <Leader>sd :call SvnModeDiffFiles(expand('<cword>'))<CR>

fun! SvnChangeList(clname,file)
	exe "!svn cl ".a:clname." ".a:file
endfunction
fun! SvnAdd(file)
	exe "!svn add ".a:file
endfunction
fun! SvnDiff(args,file)
	let argList = split(a:args,' ')
	if (empty(l:argList))
		let file = SvnModeWindow(a:file)
	else
		let file = SvnModeWindow(l:argList[0])
	endif
	if (get(l:argList,1,'') != '')
		let options = '--changelist '.l:argList[1].' '
	else
		let options = ''
	endif
	exe "r !svn diff -x ".g:svn_diff_opt." ".l:options.l:file
	setlocal filetype=diff
endfunction
fun! SvnConflictDiff(end)
	let working = []
	let merge = []
	let start = line('.')
	while (l:start <= a:end)
		let currentLine = getline(l:start)
		if (match(l:currentLine,'^<<<<<<<') >= 0)
			let blockStart = l:start + 1
		elseif (match(l:currentLine,'^=======') >= 0)
			call extend(working,getline(l:blockStart,l:start - 1))
			let blockStart = l:start + 1
		elseif (match(l:currentLine,'^>>>>>>>') >= 0)
			call extend(merge,getline(l:blockStart,l:start - 1))
		endif
		let start = l:start + 1
	endwhile
	tabe
	set bt=nofile
	vert new
	set bt=nofile
	call setline(1,l:working)
	diffthis
	wincmd p
	call setline(1,l:merge)
	diffthis
endfunction
fun! SvnLog(args,file)
	if a:args == ''
		let file = SvnModeWindow(a:file)
	else
		let file = SvnModeWindow(a:args)
	endif
	setfiletype svnlog
	exe "r !svn log -v ".l:file
endfunction
fun! SvnInfo(args,file)
	if a:args == ''
		let file = SvnModeWindow(a:file)
	else
		let file = SvnModeWindow(a:args)
	endif
	exe "r !svn info ".l:file
	setlocal filetype=yaml
endfunction
fun! SvnBlame(file)
	let file = SvnModeWindow(a:file)
	exe "r !svn blame ".l:file
endfunction
fun! SvnDiffSplit(path,file,rev)
	if a:rev == ''
		let rev = 'HEAD'
	else
		let rev = a:rev
	endif
	exe "!svn export -r ".l:rev." ".a:path."/".a:file." ~/tmp/".a:file
	exe "vert diffsplit ~/tmp/".a:file
endfunction

" svn mode
" set svn mode for this window
fun! SvnModeSet(file)
	let w:svnMode = 1
	let w:svnFile = a:file
endfunction
" create new window in svn mode
" uses given file if current window is not already in svn mode
" otherwise, closes current window, creates new, sets svnmode on it and returns svnFile from previous window
fun! SvnModeWindow(file)
	let which = tabpagenr()
	if (l:which > 0)
		let which = l:which - 1
	endif
	let title = 'SVN-'.substitute(a:file,'.*/','','')
	if !SvnMode()
		exe 'tabe '.l:title
		let file = a:file
	else
		let file = w:svnFile
"		exe "q"
		tabe
	endif
	exe('tabm '.l:which)
	setl buftype=nofile
	call SvnModeSet(l:file)
	return l:file
endfunction
" are we in svnmode?
fun! SvnMode()
	if !exists('w:svnMode') || w:svnMode == 0
		return 0
	endif
	return 1
endfunction
fun! SvnModeError()
	echo "You're not in SVN mode!"
endfunction
" given a revision string ("r1234" or "1234"), displays diff of that revision
fun! SvnModeDiff(rev)
	if SvnMode()
		" extract the rev number from the input
		let num = SvnCleanRev(a:rev)
		let file = SvnModeWindow('')
		if l:num =~ ':'
			let option = '-r'
		else
			exe "r !svn log -v -r ".l:num." ".l:file
			let option = '-c'
		endif
		exe "r !svn diff -x ".g:svn_diff_opt." ".l:option." ".l:num." ".l:file
		setl filetype=diff
	else
		call SvnModeError()
	endif
endfunction
" given a revision string, displays both before and after files in diff mode
fun! SvnModeDiffFiles(rev)
	if SvnMode()
		let num = SvnCleanRev(a:rev)
		let file = SvnModeWindow('')
		if l:num =~ ':'
			let parts = split(l:num,':')
			let start = l:parts[0]
			let end = l:parts[1]
		else
			let start = l:num - 1
			let end = l:num
		endif
		let fileParts = split(l:file,'/')
		let fileName = l:fileParts[-1]
		let startFile = '~/tmp/'.l:start.l:fileName
		let endFile = '~/tmp/'.l:end.l:fileName
		exe '!svn export -r '.l:start.' '.l:file.' '.l:startFile
		exe '!svn export -r '.l:end.' '.l:file.' '.l:endFile
		exe 'e '.l:endFile
		diffthis
		exe 'vsplit '.l:startFile
		diffthis
	endif
endfunction
" get a clean revision number from the given revision string
fun! SvnCleanRev(rev)
	let matches = matchlist(a:rev,'[^0-9]*\([0-9:]*\)[^0-9]*')
	let num = get(l:matches,1)
	return l:num
endfunction
fun! SvnModeExport()
	if SvnMode()
		let line = getline('.')
		let matches = matchlist(l:line,'[-+]\+ \(\S\+\)	\S\+ \(\d\+\)')
		let fileParts = split(l:matches[1],'/')
		if w:svnFile =~ '//' " if it's a url, we have to append it
			let exportFile = w:svnFile.'/'.l:matches[1]
		else
			let exportFile = l:matches[1]
		endif
		let tempFile = '~/tmp/'.l:fileParts[-1]
		exe '!svn export '.l:exportFile.'@'.l:matches[2].' '.l:tempFile
		exec 'tabe '.l:tempFile
		nohl
	else
		call SvnModeError()
	endif
endfunction
