<?php

if (!defined("WHMCS")) {
    die("This file cannot be accessed directly");
}

class CloudflareAPI
{
    private $email;
    private $apiToken;
    private $accountId;
    private $baseUrl = 'https://api.cloudflare.com/client/v4/';

    public function __construct($email, $apiToken, $accountId)
    {
        $this->email = $email;
        $this->apiToken = $apiToken;
        $this->accountId = $accountId;
    }

    /**
     * Make a cURL request to the Cloudflare API.
     *
     * @param string $method HTTP method (GET, POST, PUT, DELETE)
     * @param string $endpoint API endpoint (e.g., 'zones', 'zones/{zoneId}/dns_records')
     * @param array $data Request payload for POST/PUT
     * @return array
     */
    private function _call($method, $endpoint, $data = [])
    {
        // Debug logging
        logModuleCall('cfdnsmanager', 'CloudflareAPI Debug', 'API Call Start', [
            'method' => $method,
            'endpoint' => $endpoint,
            'data' => $data,
            'baseUrl' => $this->baseUrl
        ]);

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $this->baseUrl . $endpoint);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 10);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        $headers = [
            'Content-Type: application/json',
        ];

        if (!empty($this->apiToken)) {
            if (strpos($this->apiToken, '@') !== false && strlen($this->apiToken) <= 37) {
                $headers[] = 'X-Auth-Email: ' . $this->email;
                $headers[] = 'X-Auth-Key: ' . $this->apiToken;
            } else {
                $headers[] = 'Authorization: Bearer ' . $this->apiToken;
            }
        }

        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

        switch ($method) {
            case 'POST':
                curl_setopt($ch, CURLOPT_POST, true);
                curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
                break;
            case 'PUT':
                curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
                curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
                break;
            case 'PATCH':
                curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PATCH');
                curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
                break;
            case 'DELETE':
                curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'DELETE');
                break;
        }

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        // Debug logging for response
        logModuleCall('cfdnsmanager', 'CloudflareAPI Debug', 'API Call Response', [
            'method' => $method,
            'endpoint' => $endpoint,
            'httpCode' => $httpCode,
            'cURL_error' => $error,
            'response' => $response
        ]);

        if ($error) {
            return ['success' => false, 'message' => 'cURL Error: ' . $error];
        }

        $decodedResponse = json_decode($response, true);

        if ($httpCode >= 200 && $httpCode < 300 && isset($decodedResponse['success']) && $decodedResponse['success']) {
            return ['success' => true, 'result' => $decodedResponse['result']];
        } else {
            $errorMessage = 'API Error: Unknown error.';
            if (isset($decodedResponse['errors']) && is_array($decodedResponse['errors'])) {
                $errorMessages = [];
                foreach ($decodedResponse['errors'] as $err) {
                    $errorMessages[] = $err['message'] . (isset($err['code']) ? ' (Code: ' . $err['code'] . ')' : '');
                }
                $errorMessage = implode(', ', $errorMessages);
            } elseif (isset($decodedResponse['message'])) {
                $errorMessage = $decodedResponse['message'];
            }
            return ['success' => false, 'message' => $errorMessage, 'httpCode' => $httpCode, 'response' => $decodedResponse];
        }
    }

    /**
     * Add a new zone (domain) to Cloudflare.
     *
     * @param string $domain The domain name to add.
     * @param string $accountId The Cloudflare Account ID.
     * @return array
     */
    public function addZone($domain, $accountId)
    {
        $data = [
            'name' => $domain,
            'account' => ['id' => $accountId],
            'type' => 'full', // As per Cloudflare API documentation
            // Removed jump_start - we'll use manual DNS scanning instead for better control
        ];
        $response = $this->_call('POST', 'zones', $data);

        if ($response['success']) {
            return [
                'success' => true,
                'zoneId' => $response['result']['id'],
                'nameServers' => $response['result']['name_servers'],
                'message' => 'Zone added successfully.'
            ];
        } else {
            return ['success' => false, 'message' => $response['message']];
        }
    }

    /**
     * Delete a zone from Cloudflare.
     *
     * @param string $zoneId The ID of the zone to delete.
     * @return array
     */
    public function deleteZone($zoneId)
    {
        $response = $this->_call('DELETE', 'zones/' . $zoneId);
        if ($response['success']) {
            return ['success' => true, 'message' => 'Zone deleted successfully.'];
        } else {
            return ['success' => false, 'message' => $response['message']];
        }
    }

    /**
     * Check the status of a zone, including nameserver status.
     *
     * @param string $zoneId The ID of the zone.
     * @return array
     */
    public function checkZoneStatus($zoneId)
    {
        $response = $this->_call('GET', 'zones/' . $zoneId);
        if (!$response['success']) {
            return ['success' => false, 'message' => $response['message']];
        }

        $result     = is_array($response['result']) ? $response['result'] : [];
        $zoneStatus = strtolower((string) ($result['status'] ?? ''));
        $rawNameServers = $result['name_servers'] ?? [];

        // Normalisasi: lowercase + buang trailing dot untuk perbandingan aman
        $normalize = function ($nsList) {
            return array_map(function ($ns) {
                return strtolower(rtrim(trim((string) $ns), '.'));
            }, (array) $nsList);
        };
        $expectedNs = $normalize($rawNameServers);

        /*
         * Zona "active" berarti Cloudflare SENDIRI sudah memverifikasi bahwa
         * nameserver domain delegasinya mengarah ke Cloudflare — cukup sebagai
         * bukti NS match tanpa lookup tambahan.
         */
        if ($zoneStatus === 'active') {
            return [
                'success'             => true,
                'status'              => $zoneStatus,
                'nameServersMatch'    => true,
                'nameServers'         => $rawNameServers,
                'originalNameServers' => $result['original_name_servers'] ?? [],
                'message'             => 'Zone is active on Cloudflare.',
            ];
        }

        /*
         * Zona belum active (mis. 'pending'): verifikasi mandiri via DNS lookup
         * terhadap NS otoritatif domain saat ini. CATATAN: field
         * 'name_servers_match' TIDAK ADA pada respons GET zones/{id} Cloudflare,
         * sehingga pengecekan lama yang membacanya selalu gagal (null => false).
         */
        $currentNs  = [];
        $domainName = rtrim(trim((string) ($result['name'] ?? '')), '.');
        if ($domainName !== '') {
            $dnsRecords = @dns_get_record($domainName, DNS_NS);
            if (is_array($dnsRecords)) {
                $currentNs = $normalize(array_column($dnsRecords, 'target'));
            }
        }

        $matched = 0;
        foreach ($expectedNs as $ns) {
            if (in_array($ns, $currentNs, true)) {
                $matched++;
            }
        }

        // Minimal salah satu NS utama harus terlihat (biasanya ada 2)
        $requiredMatches = max(1, min(2, count($expectedNs)));
        $nameServersMatch = !empty($expectedNs) && $matched >= $requiredMatches;

        return [
            'success'             => true,
            'status'              => $zoneStatus,
            'nameServersMatch'    => $nameServersMatch,
            'nameServers'         => $rawNameServers,
            'originalNameServers' => $result['original_name_servers'] ?? [],
            'currentNameServers'  => $currentNs,
            'matchedCount'        => $matched,
            'requiredCount'       => $requiredMatches,
            'message'             => $nameServersMatch
                ? 'Live DNS check confirms nameservers point to Cloudflare.'
                : 'Live DNS check found nameservers that do not point to Cloudflare yet.',
        ];
    }

    /**
     * Get the Zone ID for a given domain.
     *
     * @param string $domain The domain name.
     * @return string|null Zone ID if found, otherwise null.
     */
    public function getZoneId($domain)
    {
        $response = $this->_call('GET', 'zones?name=' . urlencode($domain));
        if ($response['success'] && !empty($response['result'])) {
            return $response['result'][0]['id'];
        }
        return null;
    }

    /**
     * Purge all cached content for a zone (Purge Everything).
     * Endpoint: POST zones/{zone_id}/purge_cache dengan body {"purge_everything": true}
     *
     * @param string $zoneId The ID of the zone.
     * @return array ['success' => bool, 'message' => string]
     */
    public function purgeCache($zoneId)
    {
        $response = $this->_call('POST', 'zones/' . $zoneId . '/purge_cache', ['purge_everything' => true]);
        if ($response['success']) {
            return ['success' => true, 'message' => 'Cache purged successfully.'];
        }
        return [
            'success' => false,
            'message' => $response['message'] ?? 'Unknown error while purging cache.',
        ];
    }

    /**
     * Get all Page Rules (Forwarding URLs) for a zone.
     * Endpoint: GET zones/{zone_id}/pagerules
     *
     * @param string $zoneId The ID of the zone.
     * @return array ['success' => bool, 'rules' => array] atau ['success' => false, 'message' => string]
     */
    public function getPageRules($zoneId)
    {
        $response = $this->_call('GET', 'zones/' . $zoneId . '/pagerules');
        if ($response['success']) {
            return ['success' => true, 'rules' => $response['result'] ?? []];
        }
        return [
            'success' => false,
            'message' => $response['message'] ?? 'Unknown error while fetching page rules.',
        ];
    }

    /**
     * Create a forwarding Page Rule (URL redirect).
     * Endpoint: POST zones/{zone_id}/pagerules
     *
     * @param string $zoneId      The ID of the zone.
     * @param string $sourceUrl   URL pattern to match, e.g. "old.example.com/*" atau "*example.com/old-path/*".
     * @param string $targetUrl   Destination URL, supports capture groups like https://new.com/$1
     * @param int    $statusCode  301 (permanent) atau 302 (temporary).
     * @return array ['success' => bool, 'message' => string]
     */
    public function addPageRule($zoneId, $sourceUrl, $targetUrl, $statusCode = 301)
    {
        $data = [
            'targets' => [
                [
                    'target'     => 'url',
                    'constraint' => [
                        'operator' => 'matches',
                        'value'    => $sourceUrl,
                    ],
                ],
            ],
            'actions' => [
                [
                    'id'    => 'forwarding_url',
                    'value' => [
                        'url'         => $targetUrl,
                        'status_code' => (int) $statusCode === 302 ? 302 : 301,
                    ],
                ],
            ],
            'status' => 'active',
        ];

        $response = $this->_call('POST', 'zones/' . $zoneId . '/pagerules', $data);
        if ($response['success']) {
            return ['success' => true, 'message' => 'Redirect rule created successfully.', 'rule' => $response['result']];
        }
        return [
            'success' => false,
            'message' => $response['message'] ?? 'Unknown error while creating redirect rule.',
        ];
    }

    /**
     * Delete a Page Rule by ID.
     * Endpoint: DELETE zones/{zone_id}/pagerules/{rule_id}
     *
     * @param string $zoneId The ID of the zone.
     * @param string $ruleId The ID of the page rule.
     * @return array ['success' => bool, 'message' => string]
     */
    public function deletePageRule($zoneId, $ruleId)
    {
        $response = $this->_call('DELETE', 'zones/' . $zoneId . '/pagerules/' . $ruleId);
        if ($response['success']) {
            return ['success' => true, 'message' => 'Redirect rule deleted successfully.'];
        }
        return [
            'success' => false,
            'message' => $response['message'] ?? 'Unknown error while deleting redirect rule.',
        ];
    }

    /**
     * Get DNS records for a specific zone.
     *
     * @param string $zoneId The ID of the zone.
     * @return array
     */
    public function getDnsRecords($zoneId)
    {
        $response = $this->_call('GET', 'zones/' . $zoneId . '/dns_records');
        if ($response['success']) {
            return ['success' => true, 'records' => $response['result']];
        } else {
            return ['success' => false, 'message' => $response['message']];
        }
    }

    /**
     * Add a new DNS record to a zone.
     *
     * @param string $zoneId The ID of the zone.
     * @param string $type Record type (A, CNAME, MX, TXT, etc.)
     * @param string $name Record name (e.g., 'www', '@')
     * @param string $content Record content (IP address, target domain, text)
     * @param int $ttl Time To Live (1 for auto)
     * @param int|null $priority Priority for MX records
     * @param bool $proxied Whether the record should be proxied through Cloudflare
     * @param string $comment Optional comment for the record
     * @return array
     */
    public function addDnsRecord($zoneId, $type, $name, $content, $ttl = 1, $priority = null, $proxied = false, $comment = '')
    {
        $data = [
            'name' => $name,
            'ttl' => $ttl,
            'type' => $type,
            'content' => $content,
            'proxied' => $proxied,
        ];

        if (!empty($comment)) {
            $data['comment'] = $comment;
        }

        if ($priority !== null && $type === 'MX') {
            $data['priority'] = $priority;
        }

        $response = $this->_call('POST', 'zones/' . $zoneId . '/dns_records', $data);
        if ($response['success']) {
            // If proxy is enabled, configure SSL settings
            if ($proxied) {
                $sslResult = $this->configureSslForProxy($zoneId, true);
                if (!$sslResult['success']) {
                    logModuleCall('cfdnsmanager', 'SSL Config Warning', 'Failed to configure SSL for proxied record', [
                        'zoneId' => $zoneId,
                        'recordId' => $response['result']['id'],
                        'error' => $sslResult['message']
                    ]);
                }
            }

            return ['success' => true, 'result' => $response['result'], 'message' => 'DNS record added.'];
        } else {
            return ['success' => false, 'message' => $response['message']];
        }
    }

    /**
     * Update an existing DNS record.
     *
     * @param string $zoneId The ID of the zone.
     * @param string $recordId The ID of the DNS record to update.
     * @param string $type Record type
     * @param string $name Record name
     * @param string $content Record content
     * @param int $ttl Time To Live
     * @param int|null $priority Priority for MX records
     * @param bool $proxied Whether the record should be proxied through Cloudflare
     * @param string $comment Optional comment for the record
     * @return array
     */
    public function updateDnsRecord($zoneId, $recordId, $type, $name, $content, $ttl = 1, $priority = null, $proxied = false, $comment = '')
    {
        $data = [
            'name' => $name,
            'ttl' => $ttl,
            'type' => $type,
            'content' => $content,
            'proxied' => $proxied,
        ];

        if (!empty($comment)) {
            $data['comment'] = $comment;
        }

        if ($priority !== null && $type === 'MX') {
            $data['priority'] = $priority;
        }

        $response = $this->_call('PUT', 'zones/' . $zoneId . '/dns_records/' . $recordId, $data);
        if ($response['success']) {
            // Configure SSL based on proxy setting
            $sslResult = $this->configureSslForProxy($zoneId, $proxied);
            if (!$sslResult['success']) {
                logModuleCall('cfdnsmanager', 'SSL Config Warning', 'Failed to configure SSL for updated record', [
                    'zoneId' => $zoneId,
                    'recordId' => $recordId,
                    'proxied' => $proxied,
                    'error' => $sslResult['message']
                ]);
            }

            return ['success' => true, 'message' => 'DNS record updated.'];
        } else {
            return ['success' => false, 'message' => $response['message']];
        }
    }

    /**
     * Delete a DNS record.
     *
     * @param string $zoneId The ID of the zone.
     * @param string $recordId The ID of the DNS record to delete.
     * @return array
     */
    public function deleteDnsRecord($zoneId, $recordId)
    {
        $response = $this->_call('DELETE', 'zones/' . $zoneId . '/dns_records/' . $recordId);
        if ($response['success']) {
            return ['success' => true, 'message' => 'DNS record deleted.'];
        } else {
            return ['success' => false, 'message' => $response['message']];
        }
    }

    /**
     * Get SSL/TLS settings for a zone.
     *
     * @param string $zoneId The ID of the zone.
     * @return array
     */
    public function getSslSettings($zoneId)
    {
        $response = $this->_call('GET', 'zones/' . $zoneId . '/ssl/tls');
        if ($response['success']) {
            return ['success' => true, 'settings' => $response['result']];
        } else {
            return ['success' => false, 'message' => $response['message']];
        }
    }

    /**
     * Update SSL/TLS settings for a zone.
     *
     * @param string $zoneId The ID of the zone.
     * @param array $settings SSL settings to update.
     * @return array
     */
    public function updateSslSettings($zoneId, $settings)
    {
        $response = $this->_call('PATCH', 'zones/' . $zoneId . '/ssl/tls', $settings);
        if ($response['success']) {
            return ['success' => true, 'result' => $response['result'], 'message' => 'SSL settings updated.'];
        } else {
            return ['success' => false, 'message' => $response['message']];
        }
    }

    /**
     * Automatically configure SSL/TLS based on proxy settings.
     *
     * @param string $zoneId The ID of the zone.
     * @param bool $proxied Whether proxy is enabled.
     * @return array
     */
    public function configureSslForProxy($zoneId, $proxied)
    {
        if ($proxied) {
            // When proxy is enabled, configure SSL for security
            $sslSettings = [
                'always_use_https' => 'on',  // Force HTTPS
                'automatic_https_rewrites' => 'on',  // Rewrite HTTP to HTTPS
                'opportunistic_encryption' => 'on',
                'tls_1_3' => 'on',  // Enable TLS 1.3
                'ssl_recommender' => 'on'  // Use Cloudflare's SSL recommender
            ];
        } else {
            // When proxy is disabled, use more permissive SSL settings
            $sslSettings = [
                'always_use_https' => 'off',  // Don't force HTTPS
                'automatic_https_rewrites' => 'off',
                'opportunistic_encryption' => 'off'
            ];
        }

        return $this->updateSslSettings($zoneId, $sslSettings);
    }

    /**
     * Scan for DNS records on the domain and automatically add them to the zone.
     * This is useful before switching nameservers to Cloudflare.
     *
     * @param string $zoneId The ID of the zone.
     * @return array
     */
    public function scanAndImportDnsRecords($zoneId)
    {
        // First, scan for DNS records
        $scanResponse = $this->_call('POST', 'zones/' . $zoneId . '/dns_records/scan', []);
        if (!$scanResponse['success']) {
            return ['success' => false, 'message' => 'DNS scan failed: ' . $scanResponse['message']];
        }

        $scannedRecords = $scanResponse['result']['records'] ?? [];
        if (empty($scannedRecords)) {
            return [
                'success' => true,
                'records' => [],
                'added' => 0,
                'skipped' => 0,
                'message' => 'DNS scan completed. No records found to import.'
            ];
        }

        $addedCount = 0;
        $skippedCount = 0;
        $errors = [];

        // Process each scanned record
        foreach ($scannedRecords as $record) {
            // Skip certain record types that might cause issues
            $skipTypes = ['SOA', 'NS']; // SOA and NS records are usually managed by Cloudflare
            if (in_array($record['type'], $skipTypes)) {
                $skippedCount++;
                continue;
            }

            // Prepare record data for Cloudflare
            $recordData = [
                'name' => $record['name'],
                'type' => $record['type'],
                'content' => $record['content'],
                'ttl' => $record['ttl'] ?? 1,
                'proxied' => false, // Don't proxy by default for imported records
            ];

            // Add priority for MX records
            if ($record['type'] === 'MX' && isset($record['priority'])) {
                $recordData['priority'] = $record['priority'];
            }

            // Try to add the record to Cloudflare
            $addResponse = $this->_call('POST', 'zones/' . $zoneId . '/dns_records', $recordData);

            if ($addResponse['success']) {
                $addedCount++;
            } else {
                $errors[] = "Failed to add {$record['type']} record {$record['name']}: " . $addResponse['message'];
                $skippedCount++;
            }
        }

        // Simplified message as requested
        $message = "DNS scan completed";
        if ($addedCount > 0) {
            $message .= "! Added {$addedCount} records to Cloudflare.";
        }
        if ($skippedCount > 0) {
            $message .= " Skipped {$skippedCount} records.";
        }
        if (!empty($errors)) {
            $message .= " Some records may have failed to import.";
        }

        return [
            'success' => true,
            'records' => $scannedRecords,
            'added' => $addedCount,
            'skipped' => $skippedCount,
            'errors' => $errors,
            'message' => $message
        ];
    }
}