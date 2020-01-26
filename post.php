<?php
	
	$body = file_get_contents('php://input');
	$fp = fopen('request.log', 'a');
	fwrite($fp, date('m/d/Y h:i:s a', time()) . ' - ' . $body . chr(10));
	fclose($fp);

	$response = array(
		"time" => time()
	);

	header('Content-Type: application/json');
	print(json_encode($response));
	
?>