<html>
<head>
    <style>
        body { white-space: pre; font-family: monospace; }
    </style>
</head>
<body>
<script language="javascript">
    var obj = <?php
    
    function read_last_line($file) {
        $line = '';

        $f = fopen($file, 'r');
        $cursor = -1;

        fseek($f, $cursor, SEEK_END);
        $char = fgetc($f);

        /**
         * Trim trailing newline chars of the file
         */
        while ($char === "\n" || $char === "\r") {
            fseek($f, $cursor--, SEEK_END);
            $char = fgetc($f);
        }

        /**
         * Read until the start of file or first newline char
         */
        while ($char !== false && $char !== "\n" && $char !== "\r") {
            /**
             * Prepend the new char
             */
            $line = $char . $line;
            fseek($f, $cursor--, SEEK_END);
            $char = fgetc($f);
        }

        return $line;
    }

	$last = read_last_line("request.log");
    
    $e = explode("-", $last);

    print($e[1]);
    
?>    
    document.body.innerHTML = "";
    document.body.appendChild(document.createTextNode(JSON.stringify(obj, null, 4)));
</script>
</body>
</html>
