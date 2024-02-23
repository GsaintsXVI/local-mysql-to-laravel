<?php

error_reporting(E_ALL);
ini_set('display_errors', 1);
echo "PHP version: " . phpversion() . "\n";
// Check if MySQLi extension is enabled
if (!extension_loaded('mysqli')) {
    echo "MySQLi extension is not enabled.";
}
echo "PHP installation path: " . php_ini_loaded_file() . "\n";

// Set MySQL connection parameters
$dbHost = "127.0.0.1";
$dbPort = "3306";
// $dbUser = "prodmon";
// $dbPassword = "ZfA45Mk3l}Mm";
// $dbDatabase = "ls_project1db";
// $tableName = "tbl_joborder";
$dbUser = "root";
$dbPassword = 'P@$$W0rd';
$dbDatabase = "lightstar2";
$tableName = "tbl_joborder";

// Set Laravel app API endpoint
// $laravelAppEndpoint = "https://lscph.net/api/jo_v2";
$laravelAppEndpoint = "http://127.0.0.1:8000/api/jo_v2";

// Get current date and time
$timestamp = date("Y-m-d H:i:s");
$dateOnly = date("Y-m-d");

// Set the path for the log file with date and connection status in the current directory
$logFile = __DIR__ . "/output_$dateOnly.log";

// Set the path for the JSON file with date and connection status in the current directory
$jsonFile = __DIR__ . "/output_$dateOnly.json";

// Read max JobID from file
$max_jobid_file = __DIR__ . "/max_jobid.txt";

$max_jobid = file_get_contents($max_jobid_file);

// Set max JobID with default value of 1 if $max_jobid is null
$max_jobid = empty($max_jobid) ? 9800 : $max_jobid;

// Append the current timestamp and the value of $max_jobid to the log file
file_put_contents($logFile, date("Y-m-d H:i:s") . " | Max Job: $max_jobid\n", FILE_APPEND);


// Set columns for the query
$columnNames = "jo.JobOrderNo, jo.Client_ID, jo.Client_ID, jo.Status, jo.DueDate, jo.JobID, cl.ClientName";

// MySQL query
$sqlQuery = "SELECT $columnNames FROM $tableName jo LEFT JOIN tbl_client cl ON cl.clientid = jo.Client_ID WHERE jo.JobID > $max_jobid AND jo.Date >= '2024-01-01'";


// Check MySQL connection
$connection = mysqli_connect($dbHost, $dbUser, $dbPassword, $dbDatabase, $dbPort);
if (!$connection) {
    file_put_contents($logFile, date("Y-m-d H:i:s") . " | MySQL connection failed\n", FILE_APPEND);
    goto _exit;
} else {
    file_put_contents($logFile, date("Y-m-d H:i
:s") . " | MySQL connection successful\n", FILE_APPEND);
}
file_put_contents($logFile, date("Y-m-d H:i:s") . " | MySQL Query: $sqlQuery\n", FILE_APPEND);

// Execute MySQL query
$result = mysqli_query($connection, $sqlQuery);
if ($result) {
    // Check if there are rows in the result
    if (mysqli_num_rows($result) == 0) {
        file_put_contents($logFile, date("Y-m-d H:i:s") . " | Mysql Query Result: 0\n", FILE_APPEND);
    } else {
        file_put_contents($logFile, date("Y-m-d H:i:s") . " | Mysql Query Result:\n", FILE_APPEND);
        $resultArray = array(); 
        while ($row = mysqli_fetch_assoc($result)) {
           
            $sql_items = "SELECT * from tbl_joborder_items where JobOrderID = ".$row['JobOrderNo'];
            $items_res = mysqli_query($connection, $sql_items);
            if($items_res){
                if (mysqli_num_rows($result) == 0) {
                    file_put_contents($logFile, date("Y-m-d H:i:s") . " | Items: 0\n", FILE_APPEND);
                } else {
                    $jo_items = array(); // Initialize an empty array to store items
                    while ($item = mysqli_fetch_assoc($items_res)) {
                        $jo_items[] = $item;
                    }
                    $row['items']=$jo_items;
                }
            }
            $resultArray[] = $row;
            file_put_contents($logFile, date("Y-m-d H:i:s") . " | " . json_encode($row) . "\n", FILE_APPEND);
            if ($row['ClientName'] == null) {
                file_put_contents($logFile, date("Y-m-d H:i:s") . " | Aborting!.. Client name is null\n", FILE_APPEND);
                goto _exit;
            }
        }//end while

       // Send data to Laravel app using cURL
        $jsonData = json_encode($resultArray);

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $laravelAppEndpoint);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonData);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

        // Disable SSL/TLS certificate verification (not recommended for production)
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

        $response = curl_exec($ch);

        if ($response === false) {
            echo 'cURL error: ' . curl_error($ch);
        } else {
            echo 'Response from Laravel app: ' . $response;
        }

        curl_close($ch);


        // Log response
        file_put_contents($logFile,  date("Y-m-d H:i:s") . " | Response from Laravel app: " . $response . "\n", FILE_APPEND);

        if ($response != null) {
            // Decode the JSON response
            $responseData = json_decode($response, true);
            if ($responseData['status'] == "success") {
                $max_jobid = $resultArray[count($resultArray) - 1]['JobID'];
                file_put_contents($logFile, date("Y-m-d H:i:s") . " | New Max JobID: $max_jobid\n", FILE_APPEND);
            }
        }
    }
} else {
    file_put_contents($logFile, date("Y-m-d H:i:s") . " | MySQL query failed\n", FILE_APPEND);
    $errorMessage = "MySQL query failed: " . mysqli_error($connection);
    file_put_contents($logFile, date("Y-m-d H:i:s") . " | $errorMessage\n", FILE_APPEND);
    trigger_error($errorMessage, E_USER_ERROR);
    // exit;
    goto _exit;
}

// // Close connection
_exit:
mysqli_close($connection);
// Output the max JobID to the log file
file_put_contents($max_jobid_file, $max_jobid);

// Script execution completed
file_put_contents($logFile, date("Y-m-d H:i:s") . " | Script execution completed.\n", FILE_APPEND);
$separator = str_repeat("-", 150); // Adjust the number as needed
file_put_contents($logFile, "$separator\n", FILE_APPEND);
