" vim: set noet nosta sw=4 ts=4 fdm=marker :
"
" Specky!
" Mahlon E. Smith <mahlon@martini.nu>
" $Id: specky.vim 92 2008-08-06 19:49:52Z mahlon $
"

" }}}
" Hook up the functions to the user supplied key bindings. {{{
"
if exists( 'g:speckySpecSwitcherKey' )
	execute 'map ' . g:speckySpecSwitcherKey . ' :call <SID>SpecSwitcher()<CR>'
endif

if exists( 'g:speckyQuoteSwitcherKey' )
	execute 'map ' . g:speckyQuoteSwitcherKey . ' :call <SID>QuoteSwitcher()<CR>'
endif

if exists( 'g:speckyRunSpecKey' )
	execute 'map ' . g:speckyRunSpecKey . ' :call <SID>RunSpec()<CR>'
endif

if exists( 'g:speckyRunRdocKey' )
	execute 'map ' . g:speckyRunRdocKey . ' :call <SID>RunRdoc()<CR>'
endif

if exists( 'g:speckyAlignKey' )
	execute 'map ' . g:speckyAlignKey . ' :call <SID>AlignAssignment()<CR>'
endif


if exists( 'specky_loaded' )
	finish
endif
let specky_loaded = '$Rev: 92 $'


"}}}
" Menu configuration {{{
"
let s:menuloc = '&Plugin.&specky'
execute 'menu ' . s:menuloc . '.&Jump\ to\ code/spec :call <SID>SpecSwitcher()<CR>'
execute 'menu ' . s:menuloc . '.Run\ &spec :call <SID>RunSpec()<CR>'
execute 'menu ' . s:menuloc . '.&RDoc\ lookup :call <SID>RunRdoc()<CR>'
execute 'menu ' . s:menuloc . '.Rotate\ &quote\ style :call <SID>QuoteSwitcher()<CR>'
execute 'menu ' . s:menuloc . '.&Align\ assignments :call <SID>AlignAssignment()<CR>'


" }}}
" SpecSwitcher() {{{
"
" When in ruby code or an rspec BDD file, try and search recursively through
" the filesystem (within the current working directory) to find the
" respectively matching file.  (code to spec, spec to code.)
"
" This operates under the assumption that you've used chdir() to put vim into
" the top level directory of your project.
"
function! <SID>SpecSwitcher()

	" If we aren't in a ruby file (specs are ruby-mode too) then we probably
	" don't care too much about this function.
	"
	if &ft != 'ruby'
		call s:err( "Not currently in ruby-mode." )
		return
	endif

	" Ensure that we can always search recursively for files to open.
	"
	let l:orig_path = &path
	set path=**

	" Get the current buffer name, and determine if it is a spec file.
	"
	" /tmp/something/whatever/rubycode.rb ---> rubycode.rb
	" A requisite of the specfiles is that they match to the class/code file,
	" this emulates the eigenclass stuff, but doesn't require the same
	" directory structures.
	"
	" rubycode.rb ---> rubycode_spec.rb
	" 
	let l:filename     = matchstr( bufname('%'), '[0-9A-Za-z_.-]*$' )
	let l:is_spec_file = match( l:filename, '_spec.rb$' ) == -1 ? 0 : 1

	if l:is_spec_file
		let l:other_file = substitute( l:filename, '_spec\.rb$', '\.rb', '' )
	else
		let l:other_file = substitute( l:filename, '\.rb$', '_spec\.rb', '' )
	endif

	let l:bufnum = bufnr( l:other_file )
	if l:bufnum == -1
		" The file isn't currently open, so let's search for it.
		execute 'find ' . l:other_file
	else
		" We've already got an open buffer with this file, just go to it.
		execute 'buffer' . l:bufnum
	endif

	" Restore the original path.
	"
	execute 'set path=' . l:orig_path
endfunction


" }}}
" QuoteSwitcher() {{{
"
" Wrap the word under the cursor in quotes.  If in ruby mode,
" cycle between quoting styles and symbols.
"
" variable -> "variable" -> 'variable' -> :variable
"
function! <SID>QuoteSwitcher()
	let l:type = strpart( expand("<cWORD>"), 0, 1 )
	let l:word = expand("<cword>")

	if l:type == '"'
		" Double quote to single
		"
		execute ":normal viWs'" . l:word . "'"

	elseif l:type == "'"
		if &ft == "ruby"
			" Single quote to symbol
			"
			execute ':normal viWs:' . l:word
		else
			" Single quote to double
			"
			execute ':normal viWs"' . l:word . '"'
		end

	else
		" Whatever to double quote
		"
		execute ':normal viWs"' . l:word . '"'
	endif

	" Move the cursor back into the cl:word
	"
	call cursor( 0, getpos('.')[2] - 1 )
endfunction


" }}}
" RunSpec() {{{
"
" Run this function while in a spec file to run the specs within vim.
"
function! <SID>RunSpec()

	" If we're in the code instead of the spec, try and switch
	" before running tests.
	"
	let l:filename     = matchstr( bufname('%'), '[0-9A-Za-z_.-]*$' )
	let l:is_spec_file = match( l:filename, '_spec.rb$' ) == -1 ? 0 : 1
	if ( ! l:is_spec_file )
		silent call <SID>SpecSwitcher()
	endif

	let l:spec   = bufname('%')
	let l:buf    = 'specky:specrun'
	let l:bufnum = bufnr( l:buf )

	" Squash the old buffer, if it exists.
	"
	if buflisted( l:buf )
		execute 'bd! ' . l:buf
	endif

	execute ( exists('g:speckyVertSplit') ? 'vert new ' : 'new ') . l:buf
	setlocal buftype=nofile bufhidden=delete noswapfile filetype=specrun
	set foldtext='--'.getline(v:foldstart).v:folddashes

	" Set up some convenient keybindings.
	"
	nnoremap <silent> <buffer> q :close<CR>
	nnoremap <silent> <buffer> e :call <SID>FindSpecError(1)<CR>
	nnoremap <silent> <buffer> r :call <SID>FindSpecError(-1)<CR>
	nnoremap <silent> <buffer> E :call <SID>FindSpecError(0)<CR>
	nnoremap <silent> <buffer> <C-e> :let b:err_line=1<CR>

	" Default cmd for spec
	"
	if !exists( 'g:speckyRunSpecCmd' )
		let g:speckyRunSpecCmd = 'spec -fs'
	endif

	" Call spec and gather up the output
	"
	let l:cmd    =  g:speckyRunSpecCmd . ' ' . l:spec
	let l:output = system( l:cmd )
	call append( 0, split( l:output, "\n" ) )
	call append( 0, '' )
	call append( 0, 'Output of: ' . l:cmd  )
	normal gg

	" Lockdown the buffer
	"
	setlocal nomodifiable
endfunction


" }}}
" RunRdoc() {{{
"
" Get documentation for the word under the cursor.
"
function! <SID>RunRdoc()

	" If we aren't in a ruby file (specs are ruby-mode too) then we probably
	" don't care too much about this function.
	"
	if ( &ft != 'ruby' && &ft != 'rdoc' )
		call s:err( "Not currently in ruby-mode." )
		return
	endif

	" Set defaults
	"
	if !exists( 'g:speckyRunRdocCmd' )
		let g:speckyRunRdocCmd = 'ri'
	endif

	let l:buf     = 'specky:rdoc'
	let l:bufname = bufname('%')

	if ( match( l:bufname, l:buf ) != -1 )
		" Already in the rdoc buffer.  This allows us to lookup
		" something like Kernel#require.
		"
		let l:word = expand('<cWORD>')
	else
		" Not in the rdoc buffer.  This allows us to lookup
		" something like 'each' in some_hash.each { ... }
		"
		let l:word = expand('<cword>')
	endif

	" Squash the old buffer, if it exists.
	"
	if buflisted( l:buf )
		execute 'bd! ' . l:buf
	endif

	" With multiple matches, strip the comams from the cWORD.
	"
	let l:word = substitute( l:word, ',', '', 'eg' )

	execute ( exists('g:speckyVertSplit') ? 'vert new ' : 'new ') . l:buf
	setlocal buftype=nofile bufhidden=delete noswapfile filetype=rdoc
	nnoremap <silent> <buffer> q :close<CR>

	" Call the documentation and gather up the output
	"
	let l:cmd    = g:speckyRunRdocCmd . ' ' . l:word
	let l:output = system( l:cmd )
	call append( 0, split( l:output, "\n" ) )
	execute 'normal gg'

	" Lockdown the buffer
	"
	execute 'setlocal nomodifiable'
endfunction


" }}}
" FindSpecError( detail ) {{{
"
" Convenience searches for jumping to spec failures.
"
function! <SID>FindSpecError( detail )

	let l:err_str = '(FAILED\|ERROR - \d\+)$'

	if ( a:detail == 0 )
		" Find the detailed failure text for the current failure line,
		" and unfold it.
		"
		let l:orig_so = &so
		set so=100
		call search('^' . matchstr(getline('.'),'\d\+)$') )
		if has('folding')
			silent! normal za
		endif
		execute 'set so=' . l:orig_so

	else
		" Find the 'regular' failure line
		"
		if exists( 'b:err_line' )
			call cursor( b:err_line, a:detail == -1 ? 1 : strlen(getline(b:err_line)) )
		endif
		call search( l:err_str, a:detail == -1 ? 'b' : '' )
		let b:err_line = line('.')
		nohl

	endif
endfunction


" }}}
" AlignAssignment( range ) {{{
"
" Prettify =, =>, and --> lines as such.
"
function! <SID>AlignAssignment() range

	let l:pat     = '[-=]\+>\?'
	let l:white   = '\(\s\+\)\?'
	let l:longest = 0

	" First pass, find the longest lvalue in the selection, after removing
	" additional stray whitespace.
	"
	let l:curline = a:firstline
	while l:curline <= a:lastline
		" what's the separator?
		let l:char = ' ' . matchstr( getline( l:curline ), l:pat ) . ' '
		" remove stray whites
		call setline( l:curline, substitute( getline(l:curline), l:white . l:pat . l:white , l:char, '' ) )
		" is this the longest line we've seen so far?
		let l:curlength = match( getline( l:curline ), l:pat )
		let l:longest   = l:curlength > l:longest ? l:curlength : l:longest
		
		let l:curline = l:curline + 1
	endwhile

	" Second pass, expand with spaces to align assignments
	"
	let l:curline = a:firstline
	while l:curline <= a:lastline
		let l:spaces_needed = l:longest - match( getline( l:curline ), l:pat )
		let l:char = ' ' . matchstr( getline( l:curline ), l:pat ) . ' '
		call setline( l:curline, substitute( getline(l:curline), l:char, repeat( ' ', l:spaces_needed ) . l:char, ''))
		let l:curline = l:curline + 1
	endwhile
endfunction


"}}}
" s:err( msg ) "{{{
" Notify of problems in a consistent fashion.
"
function! s:err( msg )
	echohl WarningMsg|echomsg 'specky: ' . a:msg|echohl None
endfunction " }}}

