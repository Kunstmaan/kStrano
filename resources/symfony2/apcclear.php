<?php 
if (in_array(@$_SERVER['REMOTE_ADDR'], array('127.0.0.1', '::1', @$_SERVER['SERVER_ADDR']))) { 
    apc_clear_cache(); 
    apc_clear_cache('user');  
    apc_clear_cache('opcode');  
    echo json_encode(array('success' => true)); 
} else { 
    die('SUPER TOP SECRET'); 
}