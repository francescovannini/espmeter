<?php
	
	$body = file_get_contents('php://input');
	$fp = fopen('request.log', 'a');
	fwrite($fp, date('m/d/Y h:i:s a', time()) . ' - ' . $body . chr(10));
	fclose($fp);

<<<<<<< HEAD
	$response = array(
		"time" => time()
	);
=======
// Provides time sync to device
$response = array(
	"time" => microtime(true)
);
>>>>>>> d9c4b96... Restored microtime()

	header('Content-Type: application/json');
	print(json_encode($response));
	
?>