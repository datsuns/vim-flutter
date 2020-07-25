function! s:flutter_run_handler(job_id, data, event_type)
  echo a:job_id
  echo a:event_type
  echo join(a:data, '\n')
endfunction

function! flutter#devices() abort
  new
  setlocal buftype=nofile
  execute "read ! flutter devices"
  setlocal nomodifiable
endfunction

function! flutter#emulators() abort
  new
  setlocal buftype=nofile
  execute "read !" . g:flutter_command ."  emulators"
  setlocal nomodifiable
endfunction
 
function! flutter#emulators_launch(emulator) abort
  if has('nvim')
    let cmd = g:flutter_command . " emulators --launch ". a:emulator
    execute "!". cmd
  elseif v:version >= 800
    let cmd = [&shell, &shellcmdflag, g:flutter_command, 'emulators', '--launch', a:emulator]
    call job_start(cmd, {
          \ 'stoponexit': ''
          \ })
  else
    echoerr 'This vim does not support async jobs needed for running Flutter.'
  endif
endfunction

function! flutter#send(msg) abort
  if !exists('g:flutter_job')
    echoerr 'Flutter is not running.'
  else
    if has('nvim')
      call chansend(g:flutter_job, a:msg)
    else
      let chan = job_getchannel(g:flutter_job)
      call ch_sendraw(chan, a:msg)
    endif
  endif
endfunction

function! flutter#visual_debug() abort
  return flutter#send('p')
endfunction

function! flutter#hot_reload() abort
  return flutter#send('r')
endfunction

function! flutter#hot_reload_quiet() abort
  if exists('g:flutter_job')
    return flutter#send('r')
  endif
endfunction

function! flutter#hot_restart() abort
  return flutter#send('R')
endfunction

function! flutter#hot_restart_quiet() abort
  if exists('g:flutter_job')
    return flutter#send('R')
  endif
endfunction

function! flutter#quit() abort
  return flutter#send('q')
endfunction

function! flutter#_exit_cb(job, status) abort
  if exists('g:flutter_job')
    unlet g:flutter_job
  endif
  call job_stop(a:job)
endfunction

if has('nvim')
function! flutter#_on_exit_nvim(job_id, data, event) abort dict
  if exists('g:flutter_job')
    unlet g:flutter_job
  endif
endfunction

let g:flutter_partial_line_nvim = ''
function! flutter#_on_output_nvim(job_id, data, event) abort dict
  if !empty(a:data)
    " Append the first element to the previous partial line
    let g:flutter_partial_line_nvim .= a:data[0]
    " Check if any newlines to be printed
    if len(a:data) > 1
      let b = bufnr('__Flutter_Output__')
      " Print the now-finished partial line
      call nvim_buf_set_lines(b, -1, -1, v:true, [g:flutter_partial_line_nvim])
      " Print the rest of the complete lines (except the last)
      call nvim_buf_set_lines(b, -1, -1, v:true, a:data[1:-2])
      " Start the next partial line with the last element
      let g:nvim_partial_line = a:data[-1]
    endif
  endif
endfunction
endif

function! flutter#open_log_window() abort
  if g:flutter_show_log_always_tab
    tabnew __Flutter_Output__
    if g:flutter_default_output_tab_num != -1
      execute(g:flutter_default_output_tab_num . "tabmove")
    endif
  else
    split __Flutter_Output__
  endif
  normal! ggdG
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
endfunction

function! flutter#fix_run_option(arg) abort
  let fixed_opt = []
  if !empty(a:arg)
    let fixed_opt = a:arg
    if g:flutter_use_last_run_option
      let g:flutter_last_run_option = a:arg
    endif
  else
    if g:flutter_use_last_run_option && exists('g:flutter_last_run_option')
      let fixed_opt += g:flutter_last_run_option
    endif
  endif
  return fixed_opt
endfunction

function! flutter#run(...) abort
  if exists('g:flutter_job')
    echoerr 'Another Flutter process is running.'
    return 0
  endif

  if g:flutter_show_log_on_run
    call flutter#open_log_window()
  endif

  let cmd = g:flutter_command.' run'
  if !empty(a:000)
    let cmd = cmd." ".join(a:000)
    if g:flutter_use_last_run_option
      let g:flutter_last_run_option = a:000
    endif
  else
    if g:flutter_use_last_run_option && exists('g:flutter_last_run_option')
      let cmd += g:flutter_last_run_option
    endif
  endif

  if has('nvim')
    let g:flutter_job = jobstart(cmd, {
          \ 'on_stdout' : function('flutter#_on_output_nvim'),
          \ 'on_stderr' : function('flutter#_on_output_nvim'),
          \ 'on_exit' : function('flutter#_on_exit_nvim'),
          \ })
  elseif v:version >= 800
    let g:flutter_job = job_start(cmd, {
          \ 'out_io': 'buffer',
          \ 'out_name': '__Flutter_Output__',
          \ 'err_io': 'buffer',
          \ 'err_name': '__Flutter_Output__',
          \ 'exit_cb': function('flutter#_exit_cb')
          \ })

      if job_status(g:flutter_job) == 'fail'
        echo 'Starting job failed'
        unlet g:flutter_job
      endif
  else
    echoerr 'This vim does not support async jobs needed for running Flutter.'
  endif

endfunction
