#!/usr/bin/env bats

source usr/lib/outlogger.sh

load '/usr/lib/bats-support/load.bash'
load '/usr/lib/bats-assert/load.bash'
load '/usr/lib/bats-file/load.bash'

function setup() {
    rm -rf /tmp/outloggertest
}

function teardown() {
    rm -rf /tmp/outloggertest
}

@test "init_logging no path" {
    run init_logging
    
    assert_failure
    assert_output "ERROR! A valid path must be supplied to init_logging()"
}

@test "init_logging bad path" {
    run init_logging /dev/null
    
    assert_failure
    assert_output "ERROR! Unable to create /dev/null in init_logging()"
}

@test "init_logging" {
    run init_logging /tmp/outloggertest
    
    assert_success
}

@test "redirect_output_to_file no path" {
    run redirect_output_to_file
    
    assert_failure
    assert_output "ERROR! log file name required when calling redirect_output_to_file()"
}

@test "redirect_output_to_file not initialised" {
    run redirect_output_to_file test.log
    
    assert_failure
    assert_output "ERROR! Logging not initialised in redirect_output_to_file() - you must call init_logging() first"
}

@test "redirect_output_to_file double redirect" {
    
    function test_func
    {
        init_logging /tmp/outloggertest
        redirect_output_to_file test.log
        redirect_output_to_file test2.log
    }
    
    run test_func
    assert_failure
    assert_output "ERROR! logs already redirected in redirect_output_to_file()"
}

@test "redirect_output_to_file" {
    
    function test_func
    {
        init_logging /tmp/outloggertest
        redirect_output_to_file test.log
        
        echo "Frob!"
        echo "Nicate!" >&2
        
        end_log_redirect
    }
    
    run test_func
    assert_success
    assert_file_exist /tmp/outloggertest/test.log
    
    run cat /tmp/outloggertest/test.log
    assert_success
    assert_line --index 0 "Frob!"
    assert_line --index 1 "Nicate!"
}

@test "end_log_redirect no redirect" {
    run end_log_redirect
    assert_failure
    assert_output "ERROR! logs not redirected when calling end_log_redirect()"
}

@test "tee_output_to_file_stdout no path" {
    run tee_output_to_file_stdout
    
    assert_failure
    assert_output "ERROR! log file name required when calling tee_output_to_file_stdout()"
}

@test "tee_output_to_file_stdout not initialised" {
    run tee_output_to_file_stdout test.log
    
    assert_failure
    assert_output "ERROR! Logging not initialised in tee_output_to_file_stdout() - you must call init_logging() first"
}

@test "tee_output_to_file_stdout double redirect" {
    
    function test_func
    {
        init_logging /tmp/outloggertest
        tee_output_to_file_stdout test.log
        tee_output_to_file_stdout test2.log
    }
    
    run test_func
    assert_failure
    assert_output "ERROR! logs already redirected in tee_output_to_file_stdout()"
}

@test "tee_output_to_file_stdout" {
    
    function test_func
    {
        init_logging /tmp/outloggertest
        tee_output_to_file_stdout test.log
        
        echo "Frob!"
        echo "Nicate!" >&2
        
        end_log_redirect
    }
    
    run test_func
    assert_success
    assert_line --index 0 "Frob!"
    assert_line --index 1 "Nicate!"
    assert_file_exist /tmp/outloggertest/test.log
    
    run cat /tmp/outloggertest/test.log
    assert_success
    assert_line --index 0 "Frob!"
    assert_line --index 1 "Nicate!"
}

@test "exec_and_log no filename" {
    run exec_and_log
    
    assert_failure
    assert_output "ERROR! A file name is expected when calling exec_and_log()"
}

@test "exec_and_log no command" {
    run exec_and_log testfile
    
    assert_failure
    assert_output "ERROR! A command is expected when calling exec_and_log()"
}

@test "exec_and_log not initialised" {
    run exec_and_log testfile echo "frob!"
    
    assert_failure
    assert_output "ERROR! Logging not initialised when calling exec_and_log() - you must call init_logging() first"
}

@test "exec_and_log" {
    
    function test_func
    {
        init_logging /tmp/outloggertest
        exec_and_log testfile tests/sup/frobnicate.sh
        echo "${__logfiles[@]}"
    }
    
    run test_func
    assert_success
    assert_output "/tmp/outloggertest/testfile.out.log /tmp/outloggertest/testfile.err.log"
    assert_file_exist /tmp/outloggertest/testfile.out.log
    assert_file_exist /tmp/outloggertest/testfile.err.log
}

@test "exec_and_log auto-delete out" {
    
    function test_func
    {
        init_logging /tmp/outloggertest
        exec_and_log testfile tests/sup/nicate.sh
        echo "${__logfiles[@]}"
    }
    
    run test_func
    assert_success
    assert_output "/tmp/outloggertest/testfile.err.log"
    assert_file_not_exist /tmp/outloggertest/testfile.out.log
    assert_file_exist /tmp/outloggertest/testfile.err.log
}

@test "exec_and_log auto-delete err" {
    
    function test_func
    {
        init_logging /tmp/outloggertest
        exec_and_log testfile tests/sup/frob.sh
        echo "${__logfiles[@]}"
    }
    
    run test_func
    assert_success
    assert_output "/tmp/outloggertest/testfile.out.log"
    assert_file_exist /tmp/outloggertest/testfile.out.log
    assert_file_not_exist /tmp/outloggertest/testfile.err.log
}

@test "bzip_large_logs no size" {
    run bzip_large_logs
    
    assert_failure
    assert_output "ERROR! A minimum size (in bytes) is required when calling bzip_large_logs()"
}

@test "bzip_large_logs not initialised" {
    run bzip_large_logs 1024
    
    assert_failure
    assert_output "ERROR! Logging not initialised when calling bzip_large_logs() - you must call init_logging() first"
}

@test "bzip_large_logs" {
    function test_func
    {
        init_logging /tmp/outloggertest
        echo "This is short." > /tmp/outloggertest/file1.log
        echo "This is much longer and will need to be compressed." > /tmp/outloggertest/file2.log
        __logfiles+=("/tmp/outloggertest/file1.log" "/tmp/outloggertest/file2.log")
        bzip_large_logs 20
        echo "${__logfiles[@]}"
    }
    
    run test_func
    
    assert_success
    assert_output "/tmp/outloggertest/file1.log /tmp/outloggertest/file2.log.bz2"
}

@test "bzip_large_logs called twice" {
    function test_func
    {
        init_logging /tmp/outloggertest
        echo "This is short." > /tmp/outloggertest/file1.log
        echo "This is much longer and will need to be compressed." > /tmp/outloggertest/file2.log
        __logfiles+=("/tmp/outloggertest/file1.log" "/tmp/outloggertest/file2.log")
        bzip_large_logs 20
        bzip_large_logs 20
    }
    
    run test_func
    
    assert_failure
    assert_output "ERROR! Logs already bzipped when calling bzip_large_logs()"
}

@test "get_log_files not initialised" {
    run get_log_files
    
    assert_failure
    assert_output "ERROR! Logging not initialised when calling get_log_files() - you must call init_logging() first"
}

@test "get_log_files" {
    function test_func
    {
        init_logging /tmp/outloggertest
        __logfiles+=("/tmp/outloggertest/file1.log" "/tmp/outloggertest/file2.log")
        get_log_files temp
        echo "${temp[@]}"
    }
    
    run test_func
    
    assert_success
    assert_output "/tmp/outloggertest/file1.log /tmp/outloggertest/file2.log"
}

@test "send_logs_by_email no subject" {
    run send_logs_by_email
    
    assert_failure
    assert_output "ERROR! send_logs_by_email() requires a subject as parameter 1"
}

@test "send_logs_by_email no recipient" {
    run send_logs_by_email "Test"
    
    assert_failure
    assert_output "ERROR! send_logs_by_email() requires a recipient as parameter 2"
}

@test "send_logs_by_email not initialised" {
    run send_logs_by_email "Test" "test@example.com"
    
    assert_failure
    assert_output "ERROR! Logging not initialised when calling send_logs_by_email() - you must call init_logging() first"
}

@test "send_logs_by_email not redirected" {
    function test_func
    {
        init_logging /tmp/outloggertest
        send_logs_by_email "Test" "test@example.com"
    }
    
    run test_func
    
    assert_failure
    assert_output "ERROR! send_logs_by_email() requires logs to be redirected first"
}

@test "display_log_paths not initialised" {
    run display_log_paths
    
    assert_failure
    assert_output "ERROR! Logging not initialised when calling display_log_paths() - you must call init_logging() first"
}

@test "display_log_paths no logs" {
    function test_func
    {
        init_logging /tmp/outloggertest
        display_log_paths
    }
    
    run test_func
    
    assert_success
    assert_output "No log files were generated."
}

@test "display_log_paths" {
    function test_func
    {
        init_logging /tmp/outloggertest
        __logredirfile="output.log"
        __logfiles+=("/tmp/outloggertest/file1.log" "/tmp/outloggertest/file2.log")
        
        display_log_paths
    }
    
    run test_func
    
    assert_success
    assert_line --index 0 "Logs can be found at:"
    assert_line --index 1 "    /tmp/outloggertest/output.log"
    assert_line --index 2 "    /tmp/outloggertest/file1.log"
    assert_line --index 3 "    /tmp/outloggertest/file2.log"
}

@test "clean_up_logs not initialised" {
    run clean_up_logs
    
    assert_failure
    assert_output "ERROR! Logging not initialised when calling clean_up_logs() - you must call init_logging() first"
}

@test "clean_up_logs" {
    function test_func
    {
        init_logging /tmp/outloggertest
        touch /tmp/outloggertest/testfile.log
        __logfiles+=( /tmp/outloggertest/testfile.log )
        clean_up_logs
    }
    
    run test_func
    
    assert_success
    assert_file_not_exist /tmp/outloggertest/testfile.log
}
