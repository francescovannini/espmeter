<html>
<head>
  <!--<meta http-equiv="refresh" content="1">-->
</head>
<body>
<?php
	
	$lines=array();
	$fp = fopen("request.log", "r");
	while(!feof($fp))
	{
	   $line = fgets($fp, 4096);
	   array_push($lines, $line);
	   if (count($lines) > 20)
	       array_shift($lines);
	}
	fclose($fp);

	$lines = array_reverse($lines);

	foreach ($lines as $l) {
		print(htmlentities($l)) . "<br/>";
	}

?>
</body>
</html>
