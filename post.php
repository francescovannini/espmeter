<?php
	header('Content-Type: application/json');
	$body = file_get_contents('php://input');
	$fp = fopen('request.log', 'a');
	fwrite($fp, date('m/d/Y h:i:s a', time()) . ' - ' . $body . chr(10));
	fclose($fp);

	$hhh = 3600 * 3;

	$s = (date('G') * 3600 + date('i') * 60 + date('s'));
	$cycle = floor($s / $hhh);
	$secs = $hhh - $s % $hhh;

	/*$cycle = 0;
	$secs = 10;*/

	print('{"cycle": ' . $cycle . ', "seconds": ' . $secs . '}');

?>
