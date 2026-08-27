<?php

if (!defined("WHMCS")) {
    die("This file cannot be accessed directly");
}

use WHMCS\Database\Capsule;

/**
 * Create DNS records table if it doesn't exist
 */
function cfdnsmanager_createTable()
{
    try {
        if (!Capsule::schema()->hasTable('mod_cfdnsmanager_records')) {
            Capsule::schema()->create('mod_cfdnsmanager_records', function($table) {
                $table->increments('id');
                $table->integer('serviceid');
                $table->string('cloudflare_record_id')->nullable();
                $table->string('type', 10);
                $table->string('name');
                $table->text('content');
                $table->integer('ttl')->default(1);
                $table->integer('priority')->default(0);
                $table->boolean('proxied')->default(false);
                $table->enum('sync_status', ['pending', 'synced', 'failed', 'scanned'])->default('pending');
                $table->text('sync_error')->nullable();
                $table->timestamp('created_at')->useCurrent();
                $table->timestamp('updated_at')->useCurrent();
                $table->timestamp('synced_at')->nullable();

                $table->index(['serviceid', 'sync_status']);
                $table->index('cloudflare_record_id');
            });
        } else {
            // Add proxied column if it doesn't exist (for existing installations)
            try {
                // Try to add the column - this will fail silently if it already exists
                Capsule::schema()->table('mod_cfdnsmanager_records', function($table) {
                    $table->boolean('proxied')->default(false)->after('priority');
                });
            } catch (\Exception $e) {
                // Column probably already exists, ignore the error
                // Log only if it's not a "column already exists" type error
                if (strpos($e->getMessage(), 'Duplicate column') === false &&
                    strpos($e->getMessage(), 'already exists') === false) {
                    logModuleCall('cfdnsmanager', 'Database Migration', 'Unexpected error adding proxied column', $e->getMessage());
                }
            }
        }
    } catch (\Exception $e) {
        logModuleCall('cfdnsmanager', 'Database Migration', 'Unexpected error creating table', $e->getMessage());
    }
}

/**
 * Define module metadata.
 *
 * @return array
 */
function cfdnsmanager_MetaData()
{
    return array(
        'DisplayName' => 'Cloudflare DNS Manager',
        'APIVersion' => '1.1', // Use API Version 1.1
        'RequiresServer' => true, // Set true if module requires a server to work
        'DefaultNonSSLPort' => 80, // Default non-SSL port for servers
        'DefaultSSLPort' => 443, // Default SSL port for servers
        'ServiceFeatures' => array(
            'suspend' => false,
            'unsuspend' => false,
            'terminate' => true,
            'changepackage' => false,
            'changepassword' => false,
        ),
    );
}

/**
 * Define product configuration options.
 *
 * @return array
 */
function cfdnsmanager_ConfigOptions()
{
    return array(
        'Cloudflare Email' => array(
            'Type' => 'text',
            'Size' => '25',
            'Default' => '',
            'Description' => 'Enter your Cloudflare account email address.',
        ),
        'Cloudflare API Token' => array(
            'Type' => 'password',
            'Size' => '25',
            'Default' => '',
            'Description' => 'Enter your Cloudflare Global API Key or an API Token with Zone:Edit permissions.',
        ),
        'Cloudflare Account ID' => array(
            'Type' => 'text',
            'Size' => '25',
            'Default' => '',
            'Description' => 'Enter your Cloudflare Account ID.',
        ),
        'Custom Field for Zone ID' => array(
            'Type' => 'text',
            'Size' => '25',
            'Default' => 'Cloudflare Zone ID',
            'Description' => 'Enter the name of the custom field where the Cloudflare Zone ID will be stored (e.g., "Cloudflare Zone ID").',
        ),
    );
}

/**
 * Provision a new account.
 *
 * @param array $params
 * @return string
 */
function cfdnsmanager_CreateAccount(array $params)
{
    try {
        // Include the Cloudflare API class
        require_once __DIR__ . '/lib/CloudflareAPI.php';

        $cloudflareEmail = $params['configoption1'];
        $cloudflareApiToken = $params['configoption2'];
        $cloudflareAccountId = $params['configoption3'];
        $customFieldZoneIdName = $params['configoption4'];
        $domain = $params['domain'];
        $serviceId = $params['serviceid'];

        $cloudflareAPI = new CloudflareAPI($cloudflareEmail, $cloudflareApiToken, $cloudflareAccountId);

        // Add zone to Cloudflare
        $addZoneResult = $cloudflareAPI->addZone($domain, $cloudflareAccountId);

        if ($addZoneResult['success']) {
            $zoneId = $addZoneResult['zoneId'];
            $nameServers = $addZoneResult['nameServers'];

            logModuleCall(
                'cfdnsmanager',
                'CreateAccount',
                'Cloudflare Zone created for domain: ' . $domain . ' (DNS scanning available via client interface)',
                'Zone ID: ' . $zoneId . ', Nameservers: ' . implode(', ', $nameServers)
            );

            // Save Zone ID to custom field
            // First, get the custom field ID
            $customFieldId = Capsule::table('tblcustomfields')
                ->where('type', 'product')
                ->where('relid', $params['pid'])
                ->where('fieldname', $customFieldZoneIdName)
                ->value('id');

            if ($customFieldId) {
                Capsule::table('tblcustomfieldsvalues')->updateOrInsert(
                    ['fieldid' => $customFieldId, 'relid' => $serviceId],
                    ['value' => $zoneId]
                );
            } else {
                // Log error if custom field not found
                logModuleCall(
                    'cfdnsmanager',
                    'CreateAccount',
                    'Custom field for Zone ID not found: ' . $customFieldZoneIdName,
                    'Please ensure the custom field exists for this product.'
                );
                return 'Error: Custom field for Zone ID not found. Please create it in WHMCS.';
            }

            // Update nameservers in WHMCS
            if (!empty($nameServers) && is_array($nameServers)) {
                Capsule::table('tblhosting')
                    ->where('id', $serviceId)
                    ->update([
                        'ns1' => $nameServers[0],
                        'ns2' => $nameServers[1],
                    ]);
            }

            return 'success';
        } else {
            return 'Error: ' . $addZoneResult['message'];
        }
    } catch (\Exception $e) {
        logModuleCall(
            'cfdnsmanager',
            __FUNCTION__,
            $params,
            $e->getMessage(),
            $e->getTraceAsString()
        );
        return $e->getMessage();
    }
}

/**
 * Terminate an account.
 *
 * @param array $params
 * @return string
 */
function cfdnsmanager_TerminateAccount(array $params)
{
    try {
        require_once __DIR__ . '/lib/CloudflareAPI.php';

        $cloudflareEmail = $params['configoption1'];
        $cloudflareApiToken = $params['configoption2'];
        $cloudflareAccountId = $params['configoption3'];
        $customFieldZoneIdName = $params['configoption4'];
        $domain = $params['domain'];
        $serviceId = $params['serviceid'];

        $cloudflareAPI = new CloudflareAPI($cloudflareEmail, $cloudflareApiToken, $cloudflareAccountId);
    
        // Define fallback language strings if not loaded
        if (!isset($_LANG['cfdnsmanager'])) {
            $_LANG['cfdnsmanager'] = array(
                'cloudflareNameservers' => 'Cloudflare Nameservers',
                'manageDnsRecords' => 'Manage DNS Records for',
                'type' => 'Type',
                'name' => 'Name',
                'content' => 'Content',
                'ttl' => 'TTL',
                'priority' => 'Priority',
                'auto' => 'Auto',
                'addRecord' => '+',
                'existingDnsRecords' => 'Existing DNS Records',
                'noRecordsFound' => 'No DNS records found for',
                'actions' => 'Actions',
                'edit' => 'Edit',
                'delete' => 'Delete',
                'confirmDelete' => 'Are you sure you want to delete this DNS record?',
                'editDnsRecord' => 'Edit DNS Record',
                'saveChanges' => 'Save changes',
                'close' => 'Close',
                'allFieldsRequired' => 'All fields (Type, Name, Content) are required.',
                'allFieldsRequiredEdit' => 'All fields (Record ID, Type, Name, Content) are required for editing.',
                'recordAddedSuccess' => 'DNS record added successfully.',
                'recordAddedError' => 'Error adding DNS record: ',
                'recordUpdatedSuccess' => 'DNS record updated successfully.',
                'recordUpdatedError' => 'Error updating DNS record: ',
                'recordDeletedSuccess' => 'DNS record deleted successfully.',
                'recordDeletedError' => 'Error deleting DNS record: ',
                'zoneIdNotFound' => 'Cloudflare Zone ID not found for this service. Please ensure the domain is provisioned correctly.',
                'errorFetchingRecords' => 'Error fetching DNS records: ',
                'customFieldNotFound' => 'Error: Custom field for Zone ID not found. Please create it in WHMCS.',
                'cloudflareNameservers' => 'Cloudflare Nameservers for',
                'updateNameserversInstruction' => 'To use Cloudflare DNS, please update your domain\'s nameservers to the following:',
                'propagationNotice' => 'It may take up to 24-48 hours for DNS changes to propagate globally.',
                'nameserversNotAvailable' => 'Cloudflare nameservers are not yet available. Please ensure your service is provisioned correctly.',
                'howToUpdateNameservers' => 'How to Update Nameservers:',
                'step1' => 'Log in to your domain registrar\'s control panel (where you purchased your domain).',
                'step2' => 'Navigate to the DNS Management or Nameserver settings for your domain.',
                'step3' => 'Replace your current nameservers with the Cloudflare nameservers provided above.',
                'step4' => 'Save the changes. DNS propagation may take 24-48 hours.',
                'verifyNameservers' => 'Verify Nameservers',
                'nameserversVerified' => 'Nameservers successfully verified! Your domain is now active on Cloudflare.',
                'nameserversNotMatching' => 'Nameservers are not yet pointing to Cloudflare. Please ensure you have updated them at your domain registrar.',
                'errorVerifyingNameservers' => 'Error verifying nameservers: ',
                'jumpStartInfo' => 'Use the DNS scan feature below to import existing DNS records from your current nameservers before switching to Cloudflare.',
                'manualDnsMigration' => 'This ensures all your DNS records are properly migrated to avoid service disruption.',
            );
        }
    
        // Get Zone ID from custom field
        $customFieldId = Capsule::table('tblcustomfields')
            ->where('type', 'product')
            ->where('relid', $params['pid'])
            ->where('fieldname', $customFieldZoneIdName)
            ->value('id');

        $zoneId = null;
        if ($customFieldId) {
            $zoneId = Capsule::table('tblcustomfieldsvalues')
                ->where('fieldid', $customFieldId)
                ->where('relid', $serviceId)
                ->value('value');
        }

        if (!$zoneId) {
            return 'Error: Cloudflare Zone ID not found for this service.';
        }

        $deleteZoneResult = $cloudflareAPI->deleteZone($zoneId);

        if ($deleteZoneResult['success']) {
            // Optionally, remove the custom field value
            if ($customFieldId) {
                Capsule::table('tblcustomfieldsvalues')
                    ->where('fieldid', $customFieldId)
                    ->where('relid', $serviceId)
                    ->delete();
            }
            return 'success';
        } else {
            return 'Error: ' . $deleteZoneResult['message'];
        }
    } catch (\Exception $e) {
        logModuleCall(
            'cfdnsmanager',
            __FUNCTION__,
            $params,
            $e->getMessage(),
            $e->getTraceAsString()
        );
        return $e->getMessage();
    }
}

/**
 * Admin Services Tab Fields.
 *
 * @param array $params
 * @return array
 */
function cfdnsmanager_AdminServicesTabFields(array $params)
{
    try {
        require_once __DIR__ . '/lib/CloudflareAPI.php';

        $cloudflareEmail = $params['configoption1'];
        $cloudflareApiToken = $params['configoption2'];
        $cloudflareAccountId = $params['configoption3'];
        $customFieldZoneIdName = $params['configoption4'];
        $domain = $params['domain'];
        $serviceId = $params['serviceid'];
        $pid = $params['pid'];

        $cloudflareAPI = new CloudflareAPI($cloudflareEmail, $cloudflareApiToken, $cloudflareAccountId);

        $successMessage = '';
        $errorMessage = '';

        // Define fallback language strings if not loaded
        if (!isset($_LANG['cfdnsmanager'])) {
            $_LANG['cfdnsmanager'] = array(
                'cloudflareZoneId' => 'Cloudflare Zone ID',
                'notProvisioned' => 'Not Provisioned',
                'cloudflareNameservers' => 'Cloudflare Nameservers',
                'notAvailable' => 'Not Available',
                'addDomainManually' => 'Add Domain to Cloudflare Manually',
                'verifyNameservers' => 'Verify Nameservers',
                'syncFromCloudflare' => 'Sync from Cloudflare',
                'customFieldNotFound' => 'Error: Custom field for Zone ID not found. Please create it in WHMCS.',
                'domainAddedSuccess' => 'Domain successfully added to Cloudflare.',
                'errorAddingDomain' => 'Error adding domain to Cloudflare: ',
                'domainAlreadyProvisioned' => 'Domain is already provisioned in Cloudflare.',
                'nameserversVerified' => 'Nameservers successfully verified! Your domain is now active on Cloudflare.',
                'nameserversNotMatching' => 'Nameservers are not yet pointing to Cloudflare. Please ensure you have updated them at your domain registrar.',
                'errorVerifyingNameservers' => 'Error verifying nameservers: ',
                'syncZoneNotFound' => 'Domain not found in Cloudflare. Please ensure the domain is properly registered.',
                'syncSuccess' => 'Data successfully synced from Cloudflare.',
                'syncNoChanges' => 'No changes needed. Data is already up to date.',
                'syncError' => 'Error syncing data from Cloudflare: ',
                'syncZoneIdUpdated' => 'Zone ID updated from Cloudflare.',
                'syncNameserversUpdated' => 'Nameservers updated from Cloudflare.',
            );
        }

        // Get custom field ID for Zone ID
        $customFieldId = null;
        $zoneId = null;

        try {
            $customFieldId = Capsule::table('tblcustomfields')
                ->where('type', 'product')
                ->where('relid', $pid)
                ->where('fieldname', $customFieldZoneIdName)
                ->value('id');

            // Support GET actions from admin links
            if (isset($_GET['action']) && empty($_POST['cfdnsmanager_action'])) {
                $_POST['cfdnsmanager_action'] = $_GET['action'];
            }

            if ($customFieldId) {
                $zoneId = Capsule::table('tblcustomfieldsvalues')
                    ->where('fieldid', $customFieldId)
                    ->where('relid', $serviceId)
                    ->value('value');
            }
        } catch (\Exception $dbException) {
            $errorMessage = 'Database error: ' . $dbException->getMessage();
        }

        // Handle manual add zone action
        if (isset($_POST['cfdnsmanager_action']) && $_POST['cfdnsmanager_action'] === 'addZoneManually') {
            if (!$zoneId) {
                try {
                    $addZoneResult = $cloudflareAPI->addZone($domain, $cloudflareAccountId);
                    if ($addZoneResult['success']) {
                        $zoneId = $addZoneResult['zoneId'];
                        $nameServers = $addZoneResult['nameServers'];

                        // Save Zone ID to custom field
                        if ($customFieldId) {
                            Capsule::table('tblcustomfieldsvalues')->updateOrInsert(
                                ['fieldid' => $customFieldId, 'relid' => $serviceId],
                                ['value' => $zoneId]
                            );
                        } else {
                            $errorMessage = $_LANG['cfdnsmanager']['customFieldNotFound'];
                        }

                        // Update nameservers in WHMCS (nameServers from addZone already contains Cloudflare nameservers)
                        if (!empty($nameServers) && is_array($nameServers)) {
                            Capsule::table('tblhosting')
                                ->where('id', $serviceId)
                                ->update([
                                    'ns1' => $nameServers[0],
                                    'ns2' => $nameServers[1],
                                ]);
                        }
                        $successMessage = $_LANG['cfdnsmanager']['domainAddedSuccess'];
                    } else {
                        $errorMessage = $_LANG['cfdnsmanager']['errorAddingDomain'] . $addZoneResult['message'];
                    }
                } catch (\Exception $apiException) {
                    $errorMessage = 'Cloudflare API error: ' . $apiException->getMessage();
                }
            } else {
                $errorMessage = $_LANG['cfdnsmanager']['domainAlreadyProvisioned'];
            }
        }

        // Handle verify nameservers action
        if (isset($_POST['cfdnsmanager_action']) && $_POST['cfdnsmanager_action'] === 'verifyNameservers' && $zoneId) {
            try {
                $verifyResult = $cloudflareAPI->checkZoneStatus($zoneId);
                if ($verifyResult['success']) {
                    if ($verifyResult['nameServersMatch']) {
                        $successMessage = $_LANG['cfdnsmanager']['nameserversVerified'];
                    } else {
                        $errorMessage = $_LANG['cfdnsmanager']['nameserversNotMatching'];
                    }
                } else {
                    $errorMessage = $_LANG['cfdnsmanager']['errorVerifyingNameservers'] . $verifyResult['message'];
                }
            } catch (\Exception $apiException) {
                $errorMessage = 'Cloudflare API error: ' . $apiException->getMessage();
            }
        }

        // Handle sync from Cloudflare action
        if (isset($_POST['cfdnsmanager_action']) && $_POST['cfdnsmanager_action'] === 'syncFromCloudflare') {
            try {
                $syncMessages = [];
                $hasChanges = false;

                // Get current zone ID from Cloudflare
                $cloudflareZoneId = $cloudflareAPI->getZoneId($domain);

                if (!$cloudflareZoneId) {
                    $errorMessage = $_LANG['cfdnsmanager']['syncZoneNotFound'];
                } else {
                    // Check if zone ID needs updating
                    if ($zoneId !== $cloudflareZoneId) {
                        if ($customFieldId) {
                            Capsule::table('tblcustomfieldsvalues')->updateOrInsert(
                                ['fieldid' => $customFieldId, 'relid' => $serviceId],
                                ['value' => $cloudflareZoneId]
                            );
                            $syncMessages[] = $_LANG['cfdnsmanager']['syncZoneIdUpdated'];
                            $hasChanges = true;
                            $zoneId = $cloudflareZoneId; // Update local variable
                        }
                    }

                    // Get zone details including nameservers
                    $zoneDetails = $cloudflareAPI->checkZoneStatus($cloudflareZoneId);
                    if ($zoneDetails['success']) {
                        $cloudflareNameservers = $zoneDetails['nameServers'] ?? [];

                        // Get current WHMCS nameservers
                        $currentNameservers = Capsule::table('tblhosting')
                            ->where('id', $serviceId)
                            ->first(['ns1', 'ns2']);

                        $whmcsNs1 = $currentNameservers->ns1 ?? '';
                        $whmcsNs2 = $currentNameservers->ns2 ?? '';

                        // Check if nameservers need updating
                        if (!empty($cloudflareNameservers) && count($cloudflareNameservers) >= 2) {
                            if ($whmcsNs1 !== $cloudflareNameservers[0] || $whmcsNs2 !== $cloudflareNameservers[1]) {
                                Capsule::table('tblhosting')
                                    ->where('id', $serviceId)
                                    ->update([
                                        'ns1' => $cloudflareNameservers[0],
                                        'ns2' => $cloudflareNameservers[1],
                                    ]);
                                $syncMessages[] = $_LANG['cfdnsmanager']['syncNameserversUpdated'];
                                $hasChanges = true;

                                // Update local variables for display
                                $ns1 = $cloudflareNameservers[0];
                                $ns2 = $cloudflareNameservers[1];
                            }
                        }
                    } else {
                        $errorMessage = $_LANG['cfdnsmanager']['syncError'] . $zoneDetails['message'];
                    }

                    if ($hasChanges) {
                        $successMessage = $_LANG['cfdnsmanager']['syncSuccess'] . ' ' . implode(' ', $syncMessages);
                    } elseif (!$errorMessage) {
                        $successMessage = $_LANG['cfdnsmanager']['syncNoChanges'];
                    }
                }
            } catch (\Exception $syncException) {
                $errorMessage = 'Sync error: ' . $syncException->getMessage();
            }
        }
 
       // Initialize nameservers for display - only show Cloudflare nameservers
       $displayNs1 = '';
       $displayNs2 = '';

       // Get Cloudflare nameservers if zoneId is available
       if ($zoneId) {
           try {
               $zoneDetails = $cloudflareAPI->checkZoneStatus($zoneId);

               // Debug: Log the full API response
               logModuleCall('cfdnsmanager', 'AdminServicesTabFields Debug', 'Zone details API response', [
                   'zoneId' => $zoneId,
                   'success' => $zoneDetails['success'],
                   'nameServers' => $zoneDetails['nameServers'] ?? 'NOT SET',
                   'originalNameServers' => $zoneDetails['originalNameServers'] ?? 'NOT SET',
                   'full_response' => $zoneDetails
               ]);

               if ($zoneDetails['success'] && !empty($zoneDetails['nameServers']) && count($zoneDetails['nameServers']) >= 2) {
                   $displayNs1 = $zoneDetails['nameServers'][0];
                   $displayNs2 = $zoneDetails['nameServers'][1];

                   // Debug: Log the nameservers we're setting
                   logModuleCall('cfdnsmanager', 'AdminServicesTabFields Debug', 'Setting display nameservers', [
                       'displayNs1' => $displayNs1,
                       'displayNs2' => $displayNs2
                   ]);
               } else {
                   // If Cloudflare API call succeeds but no nameservers, show error
                   $errorMessage = 'Cloudflare nameservers not available. Please ensure the domain is properly provisioned in Cloudflare.';
               }
           } catch (\Exception $apiException) {
               // Log error and show error message instead of falling back
               logModuleCall('cfdnsmanager', 'AdminServicesTabFields', 'Error fetching Cloudflare nameservers for display', $apiException->getMessage());
               $errorMessage = 'Unable to fetch Cloudflare nameservers: ' . $apiException->getMessage();
           }
       } else {
           // No zone ID available
           $errorMessage = 'Cloudflare Zone ID not found. Please ensure the domain is provisioned correctly.';
       }

       $output = '
           <div class="row">
               <div class="col-md-6">
                   <div class="form-group">
                       <label>' . $_LANG['cfdnsmanager']['cloudflareZoneId'] . '</label>
                       <input type="text" class="form-control" value="' . htmlspecialchars($zoneId ?: $_LANG['cfdnsmanager']['notProvisioned']) . '" readonly>
                   </div>
               </div>
               <div class="col-md-6">
                   <div class="form-group">
                       <label>' . $_LANG['cfdnsmanager']['cloudflareNameservers'] . '</label>
                       <input type="text" class="form-control" value="' . htmlspecialchars($displayNs1 && $displayNs2 ? $displayNs1 . ', ' . $displayNs2 : $_LANG['cfdnsmanager']['notAvailable']) . '" readonly>
                   </div>
               </div>
           </div>';
 
    if (!$zoneId) {
        $output .= '<form method="post" action="" style="display: inline;"><input type="hidden" name="cfdnsmanager_action" value="addZoneManually"><button type="submit" class="btn btn-primary">' . $_LANG['cfdnsmanager']['addDomainManually'] . '</button></form>';
    } else {
        $output .= '<form method="post" action="" style="display: inline;"><input type="hidden" name="cfdnsmanager_action" value="verifyNameservers"><button type="submit" class="btn btn-info">' . $_LANG['cfdnsmanager']['verifyNameservers'] . '</button></form>';
        $output .= ' <form method="post" action="" style="display: inline;"><input type="hidden" name="cfdnsmanager_action" value="syncFromCloudflare"><button type="submit" class="btn btn-warning">' . $_LANG['cfdnsmanager']['syncFromCloudflare'] . '</button></form>';
    }
 
    if ($successMessage) {
        $output .= '<div class="alert alert-success mt-3">' . htmlspecialchars($successMessage) . '</div>';
    }
    if ($errorMessage) {
        $output .= '<div class="alert alert-danger mt-3">' . htmlspecialchars($errorMessage) . '</div>';
    }
 
        return array(
            'Cloudflare DNS Manager' => $output,
        );
    } catch (\Exception $e) {
        logModuleCall(
            'cfdnsmanager',
            __FUNCTION__,
            $params,
            $e->getMessage(),
            $e->getTraceAsString()
        );
        return array(
            'Cloudflare DNS Manager' => '<div class="alert alert-danger">Error loading Cloudflare DNS Manager: ' . htmlspecialchars($e->getMessage()) . '</div>',
        );
    }
}

/**
 * Client Area output.
 *
 * @param array $params
 * @return array
 */
function cfdnsmanager_ClientArea(array $params)
{
    // Debug: Log that client area function was called
    logModuleCall('cfdnsmanager', 'ClientArea Start', 'Client area function called', array(
        'serviceid' => $params['serviceid'] ?? 'unknown',
        'domain' => $params['domain'] ?? 'unknown',
        'pid' => $params['pid'] ?? 'unknown',
        'request_uri' => $_SERVER['REQUEST_URI'] ?? 'unknown',
        'request_method' => $_SERVER['REQUEST_METHOD'] ?? 'unknown'
    ));

    // Ensure session is started (WHMCS normally starts sessions, but be defensive)
    if (session_status() !== PHP_SESSION_ACTIVE) {
        @session_start();
    }

    // Create table if it doesn't exist
    cfdnsmanager_createTable();

    // Debug: Log table creation status
    logModuleCall('cfdnsmanager', 'Table Creation', [], 'Database table creation attempted');

    // Debug: Log that function is being called and the request method
    logModuleCall('cfdnsmanager', 'ClientArea Entry', 'Function called with params', [
        'params' => $params,
        'request_method' => $_SERVER['REQUEST_METHOD'],
        'post_data_keys' => array_keys($_POST), // Log keys to avoid logging sensitive data
        'get_data_keys' => array_keys($_GET),
    ]);

    require_once __DIR__ . '/lib/CloudflareAPI.php';

    $cloudflareEmail = $params['configoption1'];
    $cloudflareApiToken = $params['configoption2'];
    $cloudflareAccountId = $params['configoption3'];
    $customFieldZoneIdName = $params['configoption4'];
    $domain = $params['domain'];
    $serviceId = $params['serviceid'];

    $cloudflareAPI = new CloudflareAPI($cloudflareEmail, $cloudflareApiToken, $cloudflareAccountId);

    // Load language file for client area
    $language = isset($_SESSION['Language']) ? $_SESSION['Language'] : 'english';
    $langFile = __DIR__ . '/lang/' . $language . '.php';
    if (file_exists($langFile)) {
        require_once $langFile;
    } else {
        // Fallback to English if language file doesn't exist
        $langFile = __DIR__ . '/lang/english.php';
        if (file_exists($langFile)) {
            require_once $langFile;
        }
    }

    // Get Zone ID from custom field
    $customFieldId = Capsule::table('tblcustomfields')
        ->where('type', 'product')
        ->where('relid', $params['pid'])
        ->where('fieldname', $customFieldZoneIdName)
        ->value('id');

    // Debug: Log custom field lookup
    logModuleCall('cfdnsmanager', 'Custom Field Lookup', 'Looking for custom field', array(
        'customFieldName' => $customFieldZoneIdName,
        'pid' => $params['pid'],
        'serviceId' => $serviceId,
        'customFieldId' => $customFieldId
    ));

    $zoneId = null;
    if ($customFieldId) {
        $zoneId = Capsule::table('tblcustomfieldsvalues')
            ->where('fieldid', $customFieldId)
            ->where('relid', $serviceId)
            ->value('value');

        // Debug: Log zone ID retrieval
        logModuleCall('cfdnsmanager', 'Zone ID Debug', 'Zone ID retrieved', array(
            'customFieldId' => $customFieldId,
            'serviceId' => $serviceId,
            'zoneId' => $zoneId,
            'zoneIdLength' => strlen($zoneId ?? ''),
            'customFieldName' => $customFieldZoneIdName,
            'pid' => $params['pid']
        ));
    } else {
        // Debug: Log if custom field not found
        logModuleCall('cfdnsmanager', 'Zone ID Debug', 'Custom field not found', array(
            'customFieldName' => $customFieldZoneIdName,
            'pid' => $params['pid'],
            'serviceId' => $serviceId,
            'availableCustomFields' => Capsule::table('tblcustomfields')
                ->where('type', 'product')
                ->where('relid', $params['pid'])
                ->pluck('fieldname')
                ->toArray()
        ));
    }

    if (!$zoneId) {
        // Debug: Log that we're in the no zone ID branch
        logModuleCall('cfdnsmanager', 'No Zone ID Branch', 'Zone ID not found, returning error template', array(
            'domain' => $domain,
            'serviceId' => $serviceId,
            'customFieldName' => $customFieldZoneIdName
        ));

        // Ensure template file exists before returning
        $templatePath = __DIR__ . '/templates/dns_manager.tpl';
        $templateExists = file_exists($templatePath);

        logModuleCall('cfdnsmanager', 'Template Check', 'Template file check', array(
            'templatePath' => $templatePath,
            'templateExists' => $templateExists,
            'templateSize' => $templateExists ? filesize($templatePath) : 'N/A'
        ));

        if (!$templateExists) {
            logModuleCall('cfdnsmanager', 'Template Error', 'Template file not found', $templatePath);
            return array(
                'templatefile' => 'error.tpl',
                'vars' => array(
                    'error' => 'DNS Manager template file not found. Please contact administrator.'
                )
            );
        }

        // Debug: Log the return values
        logModuleCall('cfdnsmanager', 'Template Return', 'Returning template with error', array(
            'templatefile' => 'dns_manager.tpl',
            'error_message' => $_LANG['cfdnsmanager']['zoneIdNotFound'] ?? 'Zone ID not found',
            'domain' => $domain
        ));

        return array(
            'templatefile' => 'dns_manager.tpl',
            'vars' => array(
                'error' => $_LANG['cfdnsmanager']['zoneIdNotFound'],
                'localRecords' => [],
                'cloudflareRecords' => [],
                'domain' => $domain,
                'whmcsNameservers' => [], // Initialize empty if zoneId not found
                'zoneId' => null,
            ),
        );
    }

    // Get Cloudflare nameservers directly from API (like admin area does)
    $whmcsNameservers = [];
    try {
        $zoneDetails = $cloudflareAPI->checkZoneStatus($zoneId);
        logModuleCall('cfdnsmanager', 'ClientArea Nameserver Debug', 'Zone details response', [
            'success' => $zoneDetails['success'],
            'hasNameServers' => !empty($zoneDetails['nameServers']),
            'nameServerCount' => count($zoneDetails['nameServers'] ?? []),
            'nameServers' => $zoneDetails['nameServers'] ?? 'NONE'
        ]);

        if ($zoneDetails['success'] && !empty($zoneDetails['nameServers']) && count($zoneDetails['nameServers']) >= 2) {
            $whmcsNameservers = [
                $zoneDetails['nameServers'][0],
                $zoneDetails['nameServers'][1]
            ];
            logModuleCall('cfdnsmanager', 'ClientArea Nameserver Debug', 'Nameservers set from API', $whmcsNameservers);
        } else {
            logModuleCall('cfdnsmanager', 'ClientArea Nameserver Debug', 'API call successful but no nameservers returned', $zoneDetails);
        }
    } catch (\Exception $apiException) {
        logModuleCall('cfdnsmanager', 'ClientArea', 'Error fetching Cloudflare nameservers', $apiException->getMessage());
        // Fallback to WHMCS stored nameservers if API fails
        $currentNameservers = Capsule::table('tblhosting')
            ->where('id', $serviceId)
            ->first(['ns1', 'ns2']);
        $whmcsNameservers = [
            $currentNameservers->ns1 ?? '',
            $currentNameservers->ns2 ?? '',
        ];
        logModuleCall('cfdnsmanager', 'ClientArea Nameserver Debug', 'Using fallback nameservers', $whmcsNameservers);
    }

    // Ensure we always have an array with at least empty strings
    if (!is_array($whmcsNameservers)) {
        $whmcsNameservers = ['', ''];
    }
    if (count($whmcsNameservers) < 2) {
        $whmcsNameservers = array_pad($whmcsNameservers, 2, '');
    }

    $successMessage = '';
    $errorMessage = '';
    $verifyStatus = '';
    $verifyMessage = '';

    // Read any flash message set by previous actions and clear it so it can be displayed here.
    if (isset($_SESSION['cfdnsmanager_flash']) && is_array($_SESSION['cfdnsmanager_flash'])) {
        $flash = $_SESSION['cfdnsmanager_flash'];

        // Dukung format lama (keys success/error) dan format baru (status/message)
        if (!empty($flash['success'])) {
            $successMessage = $flash['success'];
        } elseif (!empty($flash['error'])) {
            $errorMessage = $flash['error'];
        } else {
            $flashStatus  = (string) ($flash['status'] ?? '');
            $flashMessage = (string) ($flash['message'] ?? '');
            if ($flashMessage !== '') {
                if ($flashStatus === 'success') {
                    $successMessage = $flashMessage;
                } elseif ($flashStatus === 'error') {
                    $errorMessage = $flashMessage;
                } else {
                    // info/warning ditampilkan via alert verifikasi (mendukung kedua kelas itu)
                    $verifyStatus  = $flashStatus === 'warning' ? 'warning' : 'info';
                    $verifyMessage = $flashMessage;
                }
            }
        }
        unset($_SESSION['cfdnsmanager_flash']);
    }

    // Also support messages passed via GET parameters when redirected back to product details.
    if (isset($_GET['cfdnsmanager_status']) && isset($_GET['cfdnsmanager_message'])) {
        $msg = trim(urldecode($_GET['cfdnsmanager_message']));
        if ($_GET['cfdnsmanager_status'] === 'success') {
            $successMessage = $msg;
        } else {
            $errorMessage = $msg;
        }
    }

    // Handle actions (Add/Edit DNS Record, Verify Nameservers)
    // Forms now explicitly use cfdnsmanager_action for module-specific actions.
    $action = $_REQUEST['cfdnsmanager_action'] ?? '';

    // Debug: Log action and all request data
    logModuleCall('cfdnsmanager', 'ClientArea Action Handler', 'Action received', array(
        'cfdnsmanager_action' => $action,
        'request_method' => $_SERVER['REQUEST_METHOD'],
        'post_data_keys' => array_keys($_POST),
        'get_data_keys' => array_keys($_GET),
        'zoneId_from_custom_field' => $zoneId,
        'domain' => $domain,
        'serviceId' => $serviceId
    ));

    if (!empty($action)) { // Only proceed if a cfdnsmanager_action is specified

        // Debug: Log POST action and all request data
        logModuleCall('cfdnsmanager', 'ClientArea POST', 'Action received', array(
            'action' => $action,
            'post_data' => $_POST,
            'get_data' => $_GET,
            'server_method' => $_SERVER['REQUEST_METHOD'],
            'zoneId_from_custom_field' => $zoneId,
            'domain' => $domain,
            'serviceId' => $serviceId
        ));

        if ($action === 'addRecord') {
            logModuleCall('cfdnsmanager', 'addRecord Flow', 'Starting addRecord action processing.', ['serviceId' => $serviceId, 'request_data' => $_REQUEST]);

            $type = trim($_REQUEST['type'] ?? '');
            $name = trim($_REQUEST['name'] ?? '');
            $content = trim($_REQUEST['content'] ?? '');
            // Decode HTML entities to prevent issues with quotes and special characters
            $content = html_entity_decode($content, ENT_QUOTES | ENT_HTML5, 'UTF-8');
            $ttl = (int) ($_REQUEST['ttl'] ?? 1); // Default to 1 (auto)
            $priority = (int) ($_REQUEST['priority'] ?? 0); // For MX records
            $proxied = isset($_REQUEST['proxied']) && $_REQUEST['proxied'] == '1'; // For A records

            // Debug: Log the form data
            logModuleCall('cfdnsmanager', 'addRecord Debug', 'Form data received', array(
                'type' => $type,
                'name' => $name,
                'content' => $content,
                'ttl' => $ttl,
                'priority' => $priority,
                'zoneId' => $zoneId,
                'domain' => $domain
            ));

            // Normalize name: allow "@" for root and append domain if user provided short name
            if ($name === '@' || $name === '') {
                $nameToUse = $domain;
            } else {
                // Ensure the name ends with the domain, but avoid double appending
                if (!preg_match('/\.?' . preg_quote($domain, '/') . '$/i', $name)) {
                    $nameToUse = rtrim($name, '.') . '.' . $domain;
                } else {
                    $nameToUse = $name;
                }
            }

            // Debug: Log normalized name
            logModuleCall('cfdnsmanager', 'addRecord Debug', 'Normalized name', array('nameToUse' => $nameToUse));

            // Validate required fields
            if (empty($type) || empty($name) || empty($content)) {
                $status = 'error';
                $msg = $_LANG['cfdnsmanager']['allFieldsRequired'];
                logModuleCall('cfdnsmanager', 'addRecord Debug', 'Validation failed', array('status' => $status, 'msg' => $msg));
            } else {
                logModuleCall('cfdnsmanager', 'addRecord Flow', 'Validation passed, attempting database insert.', ['serviceId' => $serviceId]);
                try {
                    // Step 1: Save to database first
                    $recordId = Capsule::table('mod_cfdnsmanager_records')->insertGetId([
                        'serviceid' => $serviceId,
                        'type' => $type,
                        'name' => $nameToUse,
                        'content' => $content,
                        'ttl' => $ttl,
                        'priority' => $priority,
                        'proxied' => $proxied,
                        'sync_status' => 'pending',
                        'created_at' => date('Y-m-d H:i:s'),
                        'updated_at' => date('Y-m-d H:i:s')
                    ]);

                    logModuleCall('cfdnsmanager', 'addRecord Flow', 'Database insert successful.', ['recordId' => $recordId, 'serviceId' => $serviceId]);

                    // Step 2: Try to sync to Cloudflare
                    $addResult = $cloudflareAPI->addDnsRecord($zoneId, $type, $nameToUse, $content, $ttl, $priority, $proxied, 'DNS record added via WHMCS Cloudflare DNS Manager');
                    logModuleCall('cfdnsmanager', 'addRecord Debug', 'Cloudflare API call result', $addResult);

                    if ($addResult['success']) {
                        // Update database with Cloudflare record ID and mark as synced
                        Capsule::table('mod_cfdnsmanager_records')
                            ->where('id', $recordId)
                            ->update([
                                'cloudflare_record_id' => $addResult['result']['id'] ?? null,
                                'sync_status' => 'synced',
                                'synced_at' => date('Y-m-d H:i:s'),
                                'sync_error' => null
                            ]);

                        $status = 'success';
                        $msg = $_LANG['cfdnsmanager']['recordAddedSuccess'];
                    } else {
                        // Mark as failed but keep in database
                        Capsule::table('mod_cfdnsmanager_records')
                            ->where('id', $recordId)
                            ->update([
                                'sync_status' => 'failed',
                                'sync_error' => $addResult['message']
                            ]);

                        $status = 'error';
                        $msg = $_LANG['cfdnsmanager']['recordAddedError'] . $addResult['message'] . ' (Record saved locally - you can retry sync later)';
                    }
                } catch (\Exception $e) {
                    logModuleCall('cfdnsmanager', 'addRecord Flow', 'Database insert failed with exception.', ['error' => $e->getMessage(), 'trace' => $e->getTraceAsString()]);
                    $status = 'error';
                    $msg = 'Database error: ' . $e->getMessage();
                }
            }

            // Store flash message in session
            $_SESSION['cfdnsmanager_flash'] = [
                'status' => $status,
                'message' => $msg,
            ];
            // No explicit redirect here, let WHMCS re-render the page
        } elseif ($action === 'editRecord') {
            $recordId = trim($_REQUEST['recordId'] ?? '');

            if (empty($recordId) || !preg_match('/^[a-zA-Z0-9]+$/', $recordId) || strlen($recordId) < 10) {
                $status = 'error';
                $msg = $_LANG['cfdnsmanager']['allFieldsRequiredEdit'];
                logModuleCall('cfdnsmanager', 'editRecord Debug', 'Validation failed', array('status' => $status, 'msg' => $msg));
            } else {
                $type = trim($_REQUEST['type'] ?? '');
                $name = trim($_REQUEST['name'] ?? '');
                $content = trim($_REQUEST['content'] ?? '');
                $content = html_entity_decode($content, ENT_QUOTES | ENT_HTML5, 'UTF-8');
                $ttl = (int) ($_REQUEST['ttl'] ?? 1);
                $priority = (int) ($_REQUEST['priority'] ?? 0);
                $proxied = isset($_REQUEST['proxied']) && $_REQUEST['proxied'] == '1';

                if (empty($type) || empty($name) || empty($content)) {
                    $status = 'error';
                    $msg = $_LANG['cfdnsmanager']['allFieldsRequiredEdit'];
                    logModuleCall('cfdnsmanager', 'editRecord Debug', 'Validation failed', array('status' => $status, 'msg' => $msg));
                } else {
                    if ($name === '@' || $name === '') {
                        $nameToUse = $domain;
                    } else {
                        if (!preg_match('/\.?' . preg_quote($domain, '/') . '$/i', $name)) {
                            $nameToUse = rtrim($name, '.') . '.' . $domain;
                        } else {
                            $nameToUse = $name;
                        }
                    }

                    try {
                        $editResult = $cloudflareAPI->updateDnsRecord($zoneId, $recordId, $type, $nameToUse, $content, $ttl, $priority, $proxied, 'DNS record updated via WHMCS Cloudflare DNS Manager');
                    logModuleCall('cfdnsmanager', 'editRecord Debug', 'API call result', $editResult);
                    if ($editResult['success']) {
                        // Update local database record as well
                        Capsule::table('mod_cfdnsmanager_records')
                            ->where('cloudflare_record_id', $recordId) // Assuming recordId here is Cloudflare's ID
                            ->where('serviceid', $serviceId)
                            ->update([
                                'type' => $type,
                                'name' => $nameToUse,
                                'content' => $content,
                                'ttl' => $ttl,
                                'priority' => $priority,
                                'proxied' => $proxied,
                                'sync_status' => 'synced',
                                'synced_at' => date('Y-m-d H:i:s'),
                                'sync_error' => null
                            ]);
                        $status = 'success';
                        $msg = $_LANG['cfdnsmanager']['recordUpdatedSuccess'];
                    } else {
                        // Mark local record as failed if Cloudflare update fails
                        Capsule::table('mod_cfdnsmanager_records')
                            ->where('cloudflare_record_id', $recordId)
                            ->where('serviceid', $serviceId)
                            ->update([
                                'sync_status' => 'failed',
                                'sync_error' => $editResult['message']
                            ]);
                        $status = 'error';
                        $msg = $_LANG['cfdnsmanager']['recordUpdatedError'] . $editResult['message'];
                    }
                } catch (\Exception $e) {
                    logModuleCall('cfdnsmanager', 'editRecord Debug', 'Database error', array('error' => $e->getMessage()));
                    $status = 'error';
                    $msg = 'Database error: ' . $e->getMessage();
                }
            }
        }

        // Store flash message in session
        $_SESSION['cfdnsmanager_flash'] = [
            'status' => $status,
            'message' => $msg,
        ];
    } elseif ($action === 'retrySync') {
            $localRecordId = trim($_POST['localRecordId'] ?? '');

            if (empty($localRecordId)) {
                $status = 'error';
                $msg = 'Local record ID is required.';
            } else {
                try {
                    $localRecord = Capsule::table('mod_cfdnsmanager_records')
                        ->where('id', $localRecordId)
                        ->where('serviceid', $serviceId)
                        ->first();

                    if (!$localRecord) {
                        $status = 'error';
                        $msg = 'Local record not found.';
                    } else {
                        $syncResult = $cloudflareAPI->addDnsRecord(
                            $zoneId,
                            $localRecord->type,
                            $localRecord->name,
                            $localRecord->content,
                            $localRecord->ttl,
                            $localRecord->priority,
                            !empty($localRecord->proxied),
                            'DNS record synced via WHMCS Cloudflare DNS Manager'
                        );

                        if ($syncResult['success']) {
                            Capsule::table('mod_cfdnsmanager_records')
                                ->where('id', $localRecordId)
                                ->update([
                                    'cloudflare_record_id' => $syncResult['result']['id'] ?? null,
                                    'sync_status' => 'synced',
                                    'synced_at' => date('Y-m-d H:i:s'),
                                    'sync_error' => null
                                ]);

                            $status = 'success';
                            $msg = 'Record successfully synced to Cloudflare.';
                        } else {
                            Capsule::table('mod_cfdnsmanager_records')
                                ->where('id', $localRecordId)
                                ->update([
                                    'sync_status' => 'failed',
                                    'sync_error' => $syncResult['message']
                                ]);

                            $status = 'error';
                            $msg = 'Sync failed: ' . $syncResult['message'];
                        }
                    }
                } catch (\Exception $e) {
                    $status = 'error';
                    $msg = 'Database error: ' . $e->getMessage();
                }
            }

            // Store flash message in session
            $_SESSION['cfdnsmanager_flash'] = [
                'status' => $status,
                'message' => $msg,
            ];
        } elseif ($action === 'deleteLocalRecord') {
            $localRecordId = trim($_POST['localRecordId'] ?? '');

            if (empty($localRecordId)) {
                $status = 'error';
                $msg = 'Local record ID is required.';
            } else {
                try {
                    $deleted = Capsule::table('mod_cfdnsmanager_records')
                        ->where('id', $localRecordId)
                        ->where('serviceid', $serviceId)
                        ->delete();

                    if ($deleted) {
                        $status = 'success';
                        $msg = 'Local record deleted successfully.';
                    } else {
                        $status = 'error';
                        $msg = 'Local record not found or could not be deleted.';
                    }
                } catch (\Exception $e) {
                    $status = 'error';
                    $msg = 'Database error: ' . $e->getMessage();
                }
            }

            // Store flash message in session
            $_SESSION['cfdnsmanager_flash'] = [
                'status' => $status,
                'message' => $msg,
            ];
        } elseif ($action === 'scanDnsRecords') {
            try {
                $scanResult = $cloudflareAPI->scanAndImportDnsRecords($zoneId);
                if ($scanResult['success']) {
                    $scannedRecords = $scanResult['records'];
                    $addedCount = 0;
                    $skippedCount = 0;

                    foreach ($scannedRecords as $record) {
                        // Check if record already exists in local database
                        $existingRecord = Capsule::table('mod_cfdnsmanager_records')
                            ->where('serviceid', $serviceId)
                            ->where('type', $record['type'])
                            ->where('name', $record['name'])
                            ->where('content', $record['content'])
                            ->first();

                        if (!$existingRecord) {
                            // Add to local database
                            Capsule::table('mod_cfdnsmanager_records')->insert([
                                'serviceid' => $serviceId,
                                'type' => $record['type'],
                                'name' => $record['name'],
                                'content' => $record['content'],
                                'ttl' => $record['ttl'] ?? 1,
                                'priority' => $record['priority'] ?? 0,
                                'sync_status' => 'scanned',
                                'created_at' => date('Y-m-d H:i:s'),
                                'updated_at' => date('Y-m-d H:i:s')
                            ]);
                            $addedCount++;
                        } else {
                            $skippedCount++;
                        }
                    }

                    $status = 'success';
                    $msg = "DNS scan completed! Added {$addedCount} new records, skipped {$skippedCount} existing records.";
                } else {
                    $status = 'error';
                    $msg = 'DNS scan failed: ' . $scanResult['message'];
                }
            } catch (\Exception $apiException) {
                $status = 'error';
                $msg = 'DNS scan error: ' . $apiException->getMessage();
            }

            header('Location: clientarea.php?action=productdetails&id=' . intval($serviceId) . '&cfdnsmanager_status=' . $status . '&cfdnsmanager_message=' . urlencode($msg));
            exit;
        } elseif ($action === 'verifyNameservers') {
            try {
                $verifyResult = $cloudflareAPI->checkZoneStatus($zoneId);
                logModuleCall('cfdnsmanager', 'verifyNameservers', 'Check result', $verifyResult);
                if (!empty($verifyResult['success'])) {
                    if (!empty($verifyResult['nameServersMatch'])) {
                        $verifyStatus = 'success';
                        $verifyMessage = $_LANG['cfdnsmanager']['nameserversVerified']
                            ?? 'Success! Nameservers are now pointing to Cloudflare.';
                    } else {
                        $verifyStatus = 'error';
                        $baseMsg = $_LANG['cfdnsmanager']['nameserversNotMatching']
                            ?? 'Nameservers are not yet pointing to Cloudflare.';
                        // Detail agar user tahu persisnya apa yang salah
                        $details = [];
                        $current = $verifyResult['currentNameServers'] ?? [];
                        $expected = (array) ($verifyResult['nameServers'] ?? []);
                        if (!empty($current)) {
                            $details[] = 'Detected NS: ' . implode(', ', array_slice($current, 0, 4));
                        } elseif (!empty($verifyResult['status'])) {
                            $details[] = 'Zone status at Cloudflare: "' . $verifyResult['status'] . '"';
                        }
                        if (!empty($expected)) {
                            $details[] = 'Expected NS: ' . implode(', ', array_slice($expected, 0, 4));
                        }
                        $details[] = 'DNS changes can take up to 24-48 hours to propagate.';
                        $verifyMessage = $baseMsg . ' (' . implode('. ', $details) . ')';
                    }
                } else {
                    $verifyStatus = 'error';
                    $verifyMessage = $_LANG['cfdnsmanager']['errorVerifyingNameservers'] . $verifyResult['message'];
                }
            } catch (\Exception $apiException) {
                $verifyStatus = 'error';
                $verifyMessage = 'Cloudflare API error: ' . $apiException->getMessage();
            }
        } elseif ($action === 'deleteRecord') {
            $recordId = trim($_REQUEST['recordId'] ?? '');

            // Debug: Log the delete request
            logModuleCall('cfdnsmanager', 'deleteRecord Debug', 'Delete request received', array(
                'recordId' => $recordId,
                'zoneId' => $zoneId,
                'domain' => $domain,
                'request_method' => $_SERVER['REQUEST_METHOD']
            ));

            if (empty($recordId) || !preg_match('/^[a-zA-Z0-9]+$/', $recordId) || strlen($recordId) < 10) {
                $status = 'error';
                $msg = 'Record ID is required for deletion.';
                logModuleCall('cfdnsmanager', 'deleteRecord Debug', 'Validation failed', array('status' => $status, 'msg' => $msg));
            } else {
                try {
                    $deleteResult = $cloudflareAPI->deleteDnsRecord($zoneId, $recordId);
                    logModuleCall('cfdnsmanager', 'deleteRecord Debug', 'API call result', $deleteResult);
                    if ($deleteResult['success']) {
                        // Also delete from local database
                        Capsule::table('mod_cfdnsmanager_records')
                            ->where('cloudflare_record_id', $recordId)
                            ->where('serviceid', $serviceId)
                            ->delete();
                        $status = 'success';
                        $msg = $_LANG['cfdnsmanager']['recordDeletedSuccess'];
                    } else {
                        $status = 'error';
                        $msg = $_LANG['cfdnsmanager']['recordDeletedError'] . $deleteResult['message'];
                    }
                } catch (\Exception $e) {
                    logModuleCall('cfdnsmanager', 'deleteRecord Debug', 'Database error', array('error' => $e->getMessage()));
                    $status = 'error';
                    $msg = 'Database error: ' . $e->getMessage();
                }
            }

            // Store flash message in session
            $_SESSION['cfdnsmanager_flash'] = [
                'status' => $status,
                'message' => $msg,
            ];
        } elseif ($action === 'bulkDelete') {
            // Bulk delete: array ID Cloudflare (recordIds[]) dan/atau ID lokal (localRecordIds[])
            $cloudflareIds = (isset($_REQUEST['recordIds']) && is_array($_REQUEST['recordIds'])) ? $_REQUEST['recordIds'] : [];
            $localIds      = (isset($_REQUEST['localRecordIds']) && is_array($_REQUEST['localRecordIds'])) ? $_REQUEST['localRecordIds'] : [];

            $deletedOk = 0;
            $failedItems = [];

            foreach ($cloudflareIds as $rawId) {
                $rid = trim((string) $rawId);
                if (empty($rid) || !preg_match('/^[a-zA-Z0-9]+$/', $rid)) {
                    continue;
                }
                try {
                    $deleteResult = $cloudflareAPI->deleteDnsRecord($zoneId, $rid);
                    logModuleCall('cfdnsmanager', 'bulkDelete', 'Cloudflare API result', ['recordId' => $rid, 'result' => $deleteResult]);
                    if (!empty($deleteResult['success'])) {
                        Capsule::table('mod_cfdnsmanager_records')
                            ->where('cloudflare_record_id', $rid)
                            ->where('serviceid', $serviceId)
                            ->delete();
                        $deletedOk++;
                    } else {
                        $failedItems[] = substr($rid, 0, 8) . '..: ' . $deleteResult['message'];
                    }
                } catch (\Exception $e) {
                    logModuleCall('cfdnsmanager', 'bulkDelete', 'Exception during Cloudflare delete', ['recordId' => $rid, 'error' => $e->getMessage()]);
                    $failedItems[] = substr($rid, 0, 8) . '..: ' . $e->getMessage();
                }
            }

            if (!empty($localIds)) {
                $cleanLocal = [];
                foreach ($localIds as $rawLocal) {
                    $lid = (int) $rawLocal;
                    if ($lid > 0) {
                        $cleanLocal[] = $lid;
                    }
                }
                if (!empty($cleanLocal)) {
                    try {
                        $deletedOk += Capsule::table('mod_cfdnsmanager_records')
                            ->where('serviceid', $serviceId)
                            ->whereIn('id', $cleanLocal)
                            ->delete();
                    } catch (\Exception $e) {
                        logModuleCall('cfdnsmanager', 'bulkDelete', 'Exception during local delete', ['ids' => $cleanLocal, 'error' => $e->getMessage()]);
                        $failedItems[] = 'Local: ' . $e->getMessage();
                    }
                }
            }

            if ($deletedOk > 0 && empty($failedItems)) {
                $status = 'success';
                $msg = $deletedOk . ' record(s) deleted successfully.';
            } elseif ($deletedOk > 0) {
                $status = 'error';
                $msg = $deletedOk . ' record(s) deleted, but some failed: ' . implode('; ', $failedItems);
            } else {
                $status = 'error';
                $msg = 'No records were deleted. ' . implode('; ', $failedItems);
            }

            // Store flash message in session
            $_SESSION['cfdnsmanager_flash'] = [
                'status' => $status,
                'message' => $msg,
            ];
        } elseif ($action === 'flushCache') {
            // Flush/purge seluruh cache Cloudflare untuk zona ini (Purge Everything)
            try {
                $purgeResult = $cloudflareAPI->purgeCache($zoneId);
                logModuleCall('cfdnsmanager', 'flushCache', 'Purge result', ['zoneId' => $zoneId, 'result' => $purgeResult]);
                if (!empty($purgeResult['success'])) {
                    $status = 'success';
                    $msg = 'Cloudflare cache flushed successfully for ' . $domain . '. All cached files will be re-fetched from origin.';
                } else {
                    $status = 'error';
                    $msg = 'Failed to flush Cloudflare cache: ' . $purgeResult['message'];
                }
            } catch (\Exception $e) {
                logModuleCall('cfdnsmanager', 'flushCache', 'Exception during cache purge', ['zoneId' => $zoneId, 'error' => $e->getMessage()]);
                $status = 'error';
                $msg = 'Error flushing Cloudflare cache: ' . $e->getMessage();
            }

            // Store flash message in session
            $_SESSION['cfdnsmanager_flash'] = [
                'status' => $status,
                'message' => $msg,
            ];
        } elseif ($action === 'addRedirect') {
            // Buat Page Rule forwarding (URL redirect) di Cloudflare
            $sourceUrl  = trim((string) ($_REQUEST['redirectSource'] ?? ''));
            $targetUrl  = trim((string) ($_REQUEST['redirectTarget'] ?? ''));
            $statusCode = ((int) ($_REQUEST['redirectStatus'] ?? 301) === 302) ? 302 : 301;

            if ($sourceUrl === '' || $targetUrl === '') {
                $status = 'error';
                $msg = 'Source URL pattern and target URL are required.';
            } elseif (!preg_match('#^https?://#i', $targetUrl)) {
                $status = 'error';
                $msg = 'Target URL must start with http:// or https://';
            } elseif (!filter_var($targetUrl, FILTER_VALIDATE_URL)) {
                $status = 'error';
                $msg = 'Target URL is not valid. Example: https://new-domain.com/$1';
            } else {
                try {
                    $ruleResult = $cloudflareAPI->addPageRule($zoneId, $sourceUrl, $targetUrl, $statusCode);
                    logModuleCall('cfdnsmanager', 'addRedirect', 'Page rule result', [
                        'source' => $sourceUrl,
                        'target' => $targetUrl,
                        'status' => $statusCode,
                        'result' => $ruleResult,
                    ]);
                    if (!empty($ruleResult['success'])) {
                        $status = 'success';
                        $msg = 'Redirect created: ' . $sourceUrl . ' -> ' . $targetUrl . ' (' . $statusCode . ')';
                    } else {
                        $status = 'error';
                        $msg = 'Failed to create redirect: ' . $ruleResult['message'];
                    }
                } catch (\Exception $e) {
                    logModuleCall('cfdnsmanager', 'addRedirect', 'Exception during page rule create', ['error' => $e->getMessage()]);
                    $status = 'error';
                    $msg = 'Error creating redirect: ' . $e->getMessage();
                }
            }

            // Store flash message in session
            $_SESSION['cfdnsmanager_flash'] = [
                'status' => $status,
                'message' => $msg,
            ];
        } elseif ($action === 'deleteRedirect') {
            // Hapus Page Rule berdasarkan ID
            $ruleId = trim((string) ($_REQUEST['ruleId'] ?? ''));

            if ($ruleId === '' || !preg_match('/^[a-zA-Z0-9]+$/', $ruleId)) {
                $status = 'error';
                $msg = 'A valid redirect rule ID is required.';
            } else {
                try {
                    $delRuleResult = $cloudflareAPI->deletePageRule($zoneId, $ruleId);
                    logModuleCall('cfdnsmanager', 'deleteRedirect', 'Page rule delete result', ['ruleId' => $ruleId, 'result' => $delRuleResult]);
                    if (!empty($delRuleResult['success'])) {
                        $status = 'success';
                        $msg = 'Redirect rule deleted successfully.';
                    } else {
                        $status = 'error';
                        $msg = 'Failed to delete redirect rule: ' . $delRuleResult['message'];
                    }
                } catch (\Exception $e) {
                    logModuleCall('cfdnsmanager', 'deleteRedirect', 'Exception during page rule delete', ['ruleId' => $ruleId, 'error' => $e->getMessage()]);
                    $status = 'error';
                    $msg = 'Error deleting redirect rule: ' . $e->getMessage();
                }
            }

            // Store flash message in session
            $_SESSION['cfdnsmanager_flash'] = [
                'status' => $status,
                'message' => $msg,
            ];
        } elseif ($action === 'bulkSetProxy') {
            // Bulk toggle proxy: hanya berlaku untuk tipe A/AAAA/CNAME
            $cloudflareIds = (isset($_REQUEST['recordIds']) && is_array($_REQUEST['recordIds'])) ? $_REQUEST['recordIds'] : [];
            $enableProxy   = ((string) ($_REQUEST['proxied'] ?? '0') === '1');

            $updatedOk = 0;
            $skippedItems = [];
            $failedItems = [];

            if (!empty($cloudflareIds)) {
                // Ambil seluruh record zona sekali saja untuk data lengkap tiap ID
                $allRecords = [];
                try {
                    $listResult = $cloudflareAPI->getDnsRecords($zoneId);
                    if (!empty($listResult['success'])) {
                        foreach ($listResult['records'] as $cfRec) {
                            $allRecords[$cfRec['id']] = $cfRec;
                        }
                    } else {
                        $failedItems[] = 'Failed to load zone records: ' . $listResult['message'];
                    }
                } catch (\Exception $e) {
                    $failedItems[] = 'API error: ' . $e->getMessage();
                }

                foreach ($cloudflareIds as $rawId) {
                    $rid = trim((string) $rawId);
                    if (empty($rid) || !isset($allRecords[$rid])) {
                        continue;
                    }
                    $rec = $allRecords[$rid];
                    $recType = strtoupper((string) ($rec['type'] ?? ''));

                    // Hanya A/AAAA/CNAME yang dapat diproxy oleh Cloudflare
                    if (!in_array($recType, ['A', 'AAAA', 'CNAME'], true)) {
                        $skippedItems[] = $recType . ' ' . $rec['name'];
                        continue;
                    }
                    // Lewati jika statusnya sudah sama (hemat panggilan API)
                    if ((bool) ($rec['proxied'] ?? false) === $enableProxy) {
                        $skippedItems[] = $recType . ' ' . $rec['name'] . ' (already ' . ($enableProxy ? 'on' : 'off') . ')';
                        continue;
                    }

                    try {
                        $updResult = $cloudflareAPI->updateDnsRecord(
                            $zoneId,
                            $rid,
                            $recType,
                            $rec['name'],
                            $rec['content'],
                            $rec['ttl'],
                            $rec['priority'] ?? null,
                            $enableProxy,
                            'Proxy ' . ($enableProxy ? 'enabled' : 'disabled') . ' via WHMCS Cloudflare DNS Manager'
                        );
                        logModuleCall('cfdnsmanager', 'bulkSetProxy', 'Update result', ['recordId' => $rid, 'proxied' => $enableProxy, 'result' => $updResult]);
                        if (!empty($updResult['success'])) {
                            Capsule::table('mod_cfdnsmanager_records')
                                ->where('cloudflare_record_id', $rid)
                                ->where('serviceid', $serviceId)
                                ->update(['proxied' => $enableProxy]);
                            $updatedOk++;
                        } else {
                            $failedItems[] = $recType . ' ' . $rec['name'] . ': ' . $updResult['message'];
                        }
                    } catch (\Exception $e) {
                        logModuleCall('cfdnsmanager', 'bulkSetProxy', 'Exception during proxy update', ['recordId' => $rid, 'error' => $e->getMessage()]);
                        $failedItems[] = $recType . ' ' . $rec['name'] . ': ' . $e->getMessage();
                    }
                }
            }

            if ($updatedOk > 0 && empty($failedItems)) {
                $status = 'success';
                $msg = 'Proxy ' . ($enableProxy ? 'enabled' : 'disabled') . ' for ' . $updatedOk . ' record(s).';
            } elseif ($updatedOk > 0) {
                $status = 'error';
                $msg = $updatedOk . ' record(s) updated, but some failed: ' . implode('; ', $failedItems);
            } elseif (empty($failedItems)) {
                $status = 'info';
                $msg = !empty($skippedItems)
                    ? 'No changes made. Skipped: ' . implode('; ', array_slice($skippedItems, 0, 5)) . (count($skippedItems) > 5 ? ' and ' . (count($skippedItems) - 5) . ' more.' : '. Note: only A, AAAA, and CNAME records support proxying.')
                    : 'No eligible records selected. Only A, AAAA, and CNAME records support proxying.';
            } else {
                $status = 'error';
                $msg = 'No records updated. ' . implode('; ', $failedItems);
            }

            // Store flash message in session
            $_SESSION['cfdnsmanager_flash'] = [
                'status' => $status,
                'message' => $msg,
            ];
        }
    }


    // Get local DNS records from database
    $localRecords = [];
    try {
        $localRecordsRaw = Capsule::table('mod_cfdnsmanager_records')
            ->where('serviceid', $serviceId)
            ->orderBy('created_at', 'desc')
            ->get();

        // Ensure records are arrays, not stdClass objects
        foreach ($localRecordsRaw as $record) {
            $localRecords[] = (array) $record;
        }
    } catch (\Exception $e) {
        logModuleCall('cfdnsmanager', 'ClientArea', 'Error fetching local records', $e->getMessage());
    }

    // Get current DNS records from Cloudflare
    $cloudflareRecords = [];
    if (!empty($zoneId)) {
        $getRecordsResult = $cloudflareAPI->getDnsRecords($zoneId);
        if ($getRecordsResult['success']) {
            $allRecords = $getRecordsResult['records'];
            // Filter for A, CNAME, MX, TXT records
            $allowedTypes = ['A', 'CNAME', 'MX', 'TXT'];
            foreach ($allRecords as $record) {
                // Ensure record is an array, not stdClass object
                $recordArray = (array) $record;
                if (isset($recordArray['type']) && in_array($recordArray['type'], $allowedTypes)) {
                    $cloudflareRecords[] = $recordArray;
                }
            }
        } else {
            $errorMessage = $_LANG['cfdnsmanager']['errorFetchingRecords'] . $getRecordsResult['message'];
        }
    }

    // Fetch existing Page Rules (URL redirects) for the zone - displayed in the Redirects card
    $pageRules = [];
    if (!empty($zoneId)) {
        try {
            $rulesResult = $cloudflareAPI->getPageRules($zoneId);
            if (!empty($rulesResult['success'])) {
                foreach ($rulesResult['rules'] as $rule) {
                    $ruleArray = (array) $rule;
                    // Ekstrak info yang relevan saja untuk tampilan
                    $pattern = '';
                    if (!empty($ruleArray['targets'][0]['constraint']['value'])) {
                        $pattern = (string) $ruleArray['targets'][0]['constraint']['value'];
                    }
                    $fwd = [];
                    foreach (($ruleArray['actions'] ?? []) as $act) {
                        $act = (array) $act;
                        if (($act['id'] ?? '') === 'forwarding_url') {
                            $fwd = (array) ($act['value'] ?? []);
                            break;
                        }
                    }
                    $pageRules[] = [
                        'id'         => $ruleArray['id'] ?? '',
                        'pattern'    => $pattern,
                        'target_url' => $fwd['url'] ?? '',
                        'status_code'=> $fwd['status_code'] ?? '',
                        'status'     => $ruleArray['status'] ?? 'active',
                    ];
                }
            } else {
                logModuleCall('cfdnsmanager', 'ClientArea', 'Failed to fetch page rules', $rulesResult['message']);
            }
        } catch (\Exception $e) {
            logModuleCall('cfdnsmanager', 'ClientArea', 'Exception fetching page rules', $e->getMessage());
        }
    }

    // Merge and deduplicate records - prefer Cloudflare records over local ones
    $mergedRecords = [];
    $cloudflareRecordIds = [];

    // First, add all Cloudflare records
    foreach ($cloudflareRecords as $cfRecord) {
        $mergedRecords[] = array_merge($cfRecord, [
            'source' => 'cloudflare',
            'status' => 'Cloudflare',
            'can_delete' => true
        ]);
        $cloudflareRecordIds[] = $cfRecord['id'];
    }

    // Then add local records that don't exist in Cloudflare
    foreach ($localRecords as $localRecord) {
        $existsInCloudflare = false;

        // Check if this local record has a corresponding Cloudflare record
        if (!empty($localRecord['cloudflare_record_id'])) {
            if (in_array($localRecord['cloudflare_record_id'], $cloudflareRecordIds)) {
                $existsInCloudflare = true;
            }
        } else {
            // Check by content match if no Cloudflare ID
            foreach ($cloudflareRecords as $cfRecord) {
                if ($localRecord['type'] === $cfRecord['type'] &&
                    $localRecord['name'] === $cfRecord['name'] &&
                    $localRecord['content'] === $cfRecord['content']) {
                    $existsInCloudflare = true;
                    break;
                }
            }
        }

        // Only add local record if it doesn't exist in Cloudflare
        if (!$existsInCloudflare) {
            $mergedRecords[] = array_merge($localRecord, [
                'source' => 'local',
                'status' => $localRecord['sync_status'] === 'synced' ? 'Synced' :
                           ($localRecord['sync_status'] === 'pending' ? 'Pending' :
                           ($localRecord['sync_status'] === 'failed' ? 'Failed' : 'Local')),
                'can_delete' => true
            ]);
        }
    }

    // Sort merged records by creation date (newest first)
    usort($mergedRecords, function($a, $b) {
        $dateA = isset($a['created_at']) ? strtotime($a['created_at']) : 0;
        $dateB = isset($b['created_at']) ? strtotime($b['created_at']) : 0;
        return $dateB - $dateA;
    });

    // Debug: Log template variables
    logModuleCall('cfdnsmanager', 'ClientArea Template Vars', 'Variables passed to template', array(
        'success' => $successMessage,
        'error' => $errorMessage,
        'verifyStatus' => $verifyStatus ?? null,
        'verifyMessage' => $verifyMessage ?? null,
        'hasRecords' => (!empty($localRecords) || !empty($cloudflareRecords))
    ));

    // Debug: Log final template variables
    logModuleCall('cfdnsmanager', 'Template Loading', 'Final template variables', array(
        'template' => 'dns_manager.tpl',
        'localRecordsCount' => count($localRecords),
        'cloudflareRecordsCount' => count($cloudflareRecords),
        'mergedRecordsCount' => count($mergedRecords),
        'hasZoneId' => !empty($zoneId),
        'zoneId' => $zoneId,
        'domain' => $domain,
        'hasSuccess' => !empty($successMessage),
        'hasError' => !empty($errorMessage),
        'successMessage' => $successMessage,
        'errorMessage' => $errorMessage,
        'verifyStatus' => $verifyStatus,
        'verifyMessage' => $verifyMessage,
        'whmcsNameservers' => $whmcsNameservers
    ));

    $returnArray = array(
        'templatefile' => 'dns_manager.tpl',
        'vars' => array(
            'success' => $successMessage,
            'error' => $errorMessage,
            'localRecords' => $localRecords, // Keep for backward compatibility
            'cloudflareRecords' => $cloudflareRecords, // Keep for backward compatibility
            'mergedRecords' => $mergedRecords, // New merged records array
            'domain' => $domain,
            'zoneId' => $zoneId,
            'verifyStatus' => $verifyStatus ?? null, // Pass verification status to template
            'verifyMessage' => $verifyMessage ?? null, // Pass verification message to template
            'whmcsNameservers' => $whmcsNameservers,
            'pageRules' => $pageRules ?? [], // Cloudflare Page Rules (URL redirects)
            // Language strings
            'LANG' => array(
                'cfdnsmanager' => array(
                    'cloudflareNameservers' => $_LANG['cfdnsmanager']['cloudflareNameservers'] ?? 'Cloudflare Nameservers',
                    'updateNameserversInstruction' => $_LANG['cfdnsmanager']['updateNameserversInstruction'] ?? 'To use Cloudflare DNS, please update your domain\'s nameservers to the following:',
                    'propagationNotice' => $_LANG['cfdnsmanager']['propagationNotice'] ?? 'It may take up to 24-48 hours for DNS changes to propagate globally.',
                    'howToUpdateNameservers' => $_LANG['cfdnsmanager']['howToUpdateNameservers'] ?? 'How to Update Nameservers:',
                    'step1' => $_LANG['cfdnsmanager']['step1'] ?? '1. Log in to your domain registrar\'s control panel (where you purchased your domain).',
                    'step2' => $_LANG['cfdnsmanager']['step2'] ?? '2. Navigate to the DNS Management or Nameserver settings for your domain.',
                    'step3' => $_LANG['cfdnsmanager']['step3'] ?? '3. Replace your current nameservers with the Cloudflare nameservers provided above.',
                    'step4' => $_LANG['cfdnsmanager']['step4'] ?? '4. Save the changes. DNS propagation may take 24-48 hours.',
                    'verifyNameservers' => $_LANG['cfdnsmanager']['verifyNameservers'] ?? 'Verify Nameservers',
                    'nameserversNotAvailable' => $_LANG['cfdnsmanager']['nameserversNotAvailable'] ?? 'Cloudflare nameservers are not yet available. Please ensure your service is provisioned correctly.',
                    'jumpStartInfo' => $_LANG['cfdnsmanager']['jumpStartInfo'] ?? 'Cloudflare will attempt to automatically import existing DNS records from your current nameservers. Please review the records below after provisioning.',
                    'manualDnsMigration' => $_LANG['cfdnsmanager']['manualDnsMigration'] ?? 'If records are missing, you may need to manually add them here or import them from your previous DNS provider.',
                    'manageDnsRecords' => $_LANG['cfdnsmanager']['manageDnsRecords'] ?? 'Manage DNS Records for',
                    'type' => $_LANG['cfdnsmanager']['type'] ?? 'Type',
                    'name' => $_LANG['cfdnsmanager']['name'] ?? 'Name',
                    'content' => $_LANG['cfdnsmanager']['content'] ?? 'Content',
                    'ttl' => $_LANG['cfdnsmanager']['ttl'] ?? 'TTL',
                    'priority' => $_LANG['cfdnsmanager']['priority'] ?? 'Priority',
                    'addRecord' => $_LANG['cfdnsmanager']['addRecord'] ?? '+',
                    'existingDnsRecords' => $_LANG['cfdnsmanager']['existingDnsRecords'] ?? 'Existing DNS Records',
                    'noRecordsFound' => $_LANG['cfdnsmanager']['noRecordsFound'] ?? 'No DNS records found for',
                    'actions' => $_LANG['cfdnsmanager']['actions'] ?? 'Actions',
                    'edit' => $_LANG['cfdnsmanager']['edit'] ?? 'Edit',
                    'delete' => $_LANG['cfdnsmanager']['delete'] ?? 'Delete',
                    'confirmDelete' => $_LANG['cfdnsmanager']['confirmDelete'] ?? 'Are you sure you want to delete this DNS record?',
                    'editDnsRecord' => $_LANG['cfdnsmanager']['editDnsRecord'] ?? 'Edit DNS Record',
                    'saveChanges' => $_LANG['cfdnsmanager']['saveChanges'] ?? 'Save changes',
                    'close' => $_LANG['cfdnsmanager']['close'] ?? 'Close',
                )
            ),
        ),
    );

    // Debug: Log the complete return array structure
    logModuleCall('cfdnsmanager', 'Function Return', 'Returning from ClientArea function', array(
        'templatefile' => $returnArray['templatefile'],
        'vars_keys' => array_keys($returnArray['vars']),
        'has_merged_records' => isset($returnArray['vars']['mergedRecords']),
        'merged_records_count' => count($returnArray['vars']['mergedRecords'] ?? []),
        'has_error' => !empty($returnArray['vars']['error']),
        'error_content' => $returnArray['vars']['error'] ?? 'none'
    ));

    return $returnArray;
}