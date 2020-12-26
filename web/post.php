<?php

require_once("parsetodb.php");

$body = file_get_contents('php://input');

if (strlen($body) > 0) {
	$fp = fopen('request.log', 'a');
	fwrite($fp, date('c', time()) . ' - ' . $body . chr(10));
	fclose($fp);
	parse_log($body);
}

// Provides time sync to device
$response = array(
	"time" => microtime(true)
);

header('Content-Type: application/json');
print(json_encode($response));

?>
