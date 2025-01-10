component {

	// https://sandbox.authorize.net
	//  You will need this library to convert XML to JSON - because XML sucks...
	//  https://mvnrepository.com/artifact/org.json/json/20250107

	
	variables.ds = application.ds;  // Datasource.  You will only need this is you want to log.  Check the function at the bottom for logging.
       
	//variables.exceptionsLib = application.exceptionsLib;

	variables.xmlToJsonObj = createobject("java", "org.json.XML");
	
	if( application.mode eq "dev" || application.mode eq "stage") {
		variables.apilogin = "xxxxxx";
		variables.transkey = "xxxxxxx";
		variables.endpoint = "https://apitest.authorize.net/xml/v1/request.api";
	}
	else {
		variables.apilogin = "xxxx";
		variables.transkey = "xxxxx";
		variables.endpoint = "https://api.authorize.net/xml/v1/request.api";	
	}
	
	
	
	//--------------------------------------------- credit card functions ---------------------------------------------------------------------
	
	
	// subscription developers guide: https://developer.authorize.net/api/reference/features/recurring-billing.html

	struct function createSubscription(
		required string subscriptionName, // max 50 characters
		date firstPaymentDate = Now(), // includes trial
		numeric totalPaymentOccurrences = 9999,
		numeric trialPaymentOccurrences = 0,
		paymentIntervalUnit = "months", // days or months
		paymentIntervalLength = 1,
		numeric paymentAmount,
		numeric trialPaymentAmount = 0,
		required ccNumber,
		required ccExp, // yyyy-mm
		required cardCode,
		billToFirstName = "",
		billToLastName = "",
		subscriptionRefNum = "",
		customerEmail = "",
		string subscriptionId = ""
	) {
		// https =//developer.authorize.net/api/reference/index.html#payment-transactions-void-a-transaction
		// set totalPaymentOccurrences to 9999 for an ongoing subscription
		
		var requestBody = [
			"ARBCreateSubscriptionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"subscription" = [
					"name" = arguments.subscriptionName,
					"paymentSchedule" = [
						"interval" = [
							"length" = paymentIntervalLength,
							"unit" = paymentIntervalUnit
						],
						"startDate" = DateFormat(arguments.firstPaymentDate, "yyyy-mm-dd"),
						"totalOccurrences" = arguments.totalPaymentOccurrences,
						"trialOccurrences" = arguments.trialPaymentOccurrences
					],
					"amount" = arguments.paymentAmount,
					"trialAmount" = arguments.trialPaymentAmount,
					"payment" = [
						"creditCard" = [
							"cardNumber" = arguments.ccNumber,
							"expirationDate" = arguments.ccExp,
							"cardCode" = arguments.cardCode
						]
					],
					"order" = [
						"invoiceNumber" = replace(arguments.subscriptionRefNum, "-", "", "all")
					],
					"customer" = [
						"email" = arguments.customerEmail
					],		
					"billTo" = [
						"firstName" = arguments.billToFirstName,
						"lastName" = arguments.billToLastName
					]
				]			
			]
		];
	
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}

	struct function updateSubscriptionNameAmount(
		required string authorizeSubscriptionId,
		required string subscriptionName, // max 50 characters
		required paymentAmount,
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#recurring-billing-get-subscription
		// rules regarding subscription updates from developers guide:
		// - The subscription start date (subscription.paymentSchedule.startDate) may only be updated if no successful payments have been completed. 
		// - The subscription interval information (subscription.paymentSchedule.interval.length and subscription.paymentSchedule.interval.unit) may not be updated. 
		// - The number of trial occurrences (subscription.paymentSchedule.trialOccurrences) may only be updated if the subscription has not yet begun or is still in the trial period. 
		// - If the start date is the 31st, and the interval is monthly, the billing date is the last day of each month (even when the month does not have 31 days). 
		
		var requestBody = [
			"ARBUpdateSubscriptionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"subscriptionId" = arguments.authorizeSubscriptionId,				
				"subscription" = [
					"name" = arguments.subscriptionName,
					"amount" = arguments.paymentAmount
				]
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}

	struct function updateSubscriptionPaymentSchedule(
		required string authorizeSubscriptionId,
		required paymentIntervalUnit, // days or months
		required paymentIntervalLength,
		required numeric paymentAmount,
		required date firstPaymentDate,
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#recurring-billing-get-subscription
		// this isnt going to work. Authorizedotnet does not allow changes to the payment interval even if the start date is in the future.
		
		var requestBody = [
			"ARBUpdateSubscriptionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"subscriptionId" = arguments.authorizeSubscriptionId,				
				"subscription" = [
					"paymentSchedule" = [
						"interval" = [
							"length" = arguments.paymentIntervalLength,
							"unit" = arguments.paymentIntervalUnit
						],
						"startDate" = DateFormat(arguments.firstPaymentDate, "yyyy-mm-dd"),
						"totalOccurrences" = 9999,
						"trialOccurrences" = 0
					],
					"amount" = arguments.paymentAmount
				]
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}


	struct function updateSubscriptionPayment(
		required string authorizeSubscriptionId,
		required string ccNumber,
		required string ccExp, // yyyy-mm
		required cardCode,
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#recurring-billing-get-subscription

		// upon success, this function will result in a new payment profile id being generated for this subscription, 
		// the customer profile id will remain the same
		
		var requestBody = [
			"ARBUpdateSubscriptionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"subscriptionId" = arguments.authorizeSubscriptionId,				
				"subscription" = [
					"payment" = [
						"creditCard" = [
							"cardNumber" = arguments.ccNumber,
							"expirationDate" = arguments.ccExp,
							"cardCode" = arguments.cardCode
						]
					]
				]
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}

	
	struct function getSubscription(
		required string authorizeSubscriptionId,
		includeTransactions = true,
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#recurring-billing-get-subscription
		
		var requestBody = [
			"ARBGetSubscriptionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"subscriptionId" = arguments.authorizeSubscriptionId,
				"includeTransactions" = arguments.includeTransactions
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}
	
	
	struct function getSubscriptionStatus(
		required string authorizeSubscriptionId,
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#recurring-billing-get-subscription
		
		var requestBody = [
			"ARBGetSubscriptionStatusRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"subscriptionId" = arguments.authorizeSubscriptionId
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}

	


	struct function getSubscriptions(
		searchType = "subscriptionActive",
		offset = 1,
		limit = 1000,
		orderBy = "createTimeStampUTC",
		orderDescending = true,
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#recurring-billing-cancel-a-subscription
		// searchType options: cardExpiringThisMonth, subscriptionActive, subscriptionInactive, or subscriptionExpiringThisMonth
		// orderBy options: id, name, status, createTimeStampUTC, lastName, firstName, accountNumber, amount, pastOccurences
		
		var requestBody = [
			"ARBGetSubscriptionListRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"searchType" = arguments.searchType,
				"sorting" = [
					"orderBy" = arguments.orderBy,
					"orderDescending" = arguments.orderDescending
				],
				"paging" = [
					"limit" = arguments.limit,
					"offset" = arguments.offset
				]
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}

		
	struct function cancelSubscription(
		required string authorizeSubscriptionId,
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#recurring-billing-cancel-a-subscription
		
		var requestBody = [
			"ARBCancelSubscriptionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"subscriptionId" = arguments.authorizeSubscriptionId
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}


	//--------------------------------------------- customer profile functions ---------------------------------------------------------------------
	
	
	struct function getCustomerProfile(
		required string customerProfileId,
		unmaskExpirationDate = "true",
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#customer-profiles-get-customer-profile
		
		var requestBody = [
			"getCustomerProfileRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"customerProfileId" = arguments.customerProfileId,
				"unmaskExpirationDate" = arguments.unmaskExpirationDate
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}
	
	//--------------------------------------------- customer payment profile functions -------------------------------------------------------------
	
	struct function getCustomerPaymentProfile(
		required string customerProfileId,
		required string customerPaymentProfileId,
		unmaskExpirationDate = "true",
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#customer-profiles-get-customer-payment-profile
		
		var requestBody = [
			"getCustomerPaymentProfileRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"customerProfileId" = arguments.customerProfileId,
				"customerPaymentProfileId" = arguments.customerPaymentProfileId,
				"unmaskExpirationDate" = arguments.unmaskExpirationDate
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}
	
	
	//--------------------------------------------- credit card functions ---------------------------------------------------------------------
	
	
	struct function authorize(
		required amount,
		required ccNumber,
		required ccExp, // yyyy-mm
		required ccCVV2,
		ccFirstName = "",
		ccLastName = "",
		ccCompany = "",
		ccAddress = "",
		ccCity = "",
		ccState = "",
		ccZipCode = "",
		ccCountry = "US",		
		subscriptionRefNum = "", // customerId 20 characters max!
		customerEmail = "",
		customerIP = ipAddress = StructKeyExists(getHttpRequestData(false).headers, "X-Forwarded-For") ? getHttpRequestData().headers["X-Forwarded-For"] : cgi.remote_addr,
		userId = "",
		subscriptionId = "",
		boolean isFirstRecurringPayment = false,
		boolean isFirstSubsequentAuth = false,
		boolean isSubsequentAuth = false,
		boolean isStoredCredentials = false
	) {
		// https://developer.authorize.net/api/reference/index.html#payment-transactions-authorize-a-credit-card
		
		var requestBody = [
			"createTransactionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"transactionRequest" = [
					"transactionType" = "authOnlyTransaction",		
					"amount" = arguments.amount,
					"currencyCode" = "USD",
					"payment" = [
						"creditCard" = [
							"cardNumber" = arguments.ccNumber,
							"expirationDate" = arguments.ccExp,
							"cardCode" = arguments.ccCvv2
						]
					],
					"order" = [
						"invoiceNumber" = replace(arguments.subscriptionRefNum, "-", "", "all")
					],					
					"customer" = [
						"email" = arguments.customerEmail
					],
					"billTo" = [
						"firstName" = arguments.ccFirstName,
						"lastName" = arguments.ccLastName,
						"company" = arguments.ccCompany,
						"address" = arguments.ccAddress,
						"city" = arguments.ccCity,
						"state" = arguments.ccState,
						"zip" = arguments.ccZipcode,
						"country" = arguments.ccCountry
					],
					"customerIP" = arguments.customerIP,
					"processingOptions" = [
						"isFirstRecurringPayment" = arguments.isFirstRecurringPayment,
						"isFirstSubsequentAuth" = arguments.isFirstSubsequentAuth,
						"isSubsequentAuth" = arguments.isSubsequentAuth,
						"isStoredCredentials" = arguments.isStoredCredentials
					],			
					"authorizationIndicatorType" = [
						"authorizationIndicator" = "final"
					]
				]			
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), userId = arguments.userId, subscriptionId = arguments.subscriptionId );
	}

	
	struct function capture(
		required refTransId,
		required amount,
		userId = "",
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#payment-transactions-capture-a-previously-authorized-amount
		
		var requestBody = [
			"createTransactionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"transactionRequest" = [
					"transactionType": "priorAuthCaptureTransaction",
					"amount": arguments.amount,
					"currencyCode" = "USD",
					"refTransId": arguments.refTransId
				]			
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), userId = arguments.userId, subscriptionId = arguments.subscriptionId );
	}


	struct function charge(
		required amount,
		required ccNumber,
		required ccExp, // yyyy-mm
		required ccCVV2,
		ccFirstName = "",
		ccLastName = "",
		ccCompany = "",
		ccAddress = "",
		ccCity = "",
		ccState = "",
		ccZipCode = "",
		ccCountry = "US",
		customerEmail = "",
		// customerId 20 characters max!
		customerId = "",
		customerIP = ipAddress = StructKeyExists(getHttpRequestData(false).headers, "X-Forwarded-For") ? getHttpRequestData().headers["X-Forwarded-For"] : cgi.remote_addr,
		userId = "",
		subscriptionId = "",
		boolean isFirstRecurringPayment = false,
		boolean isFirstSubsequentAuth = false,
		boolean isSubsequentAuth = false,
		boolean isStoredCredentials = false
	) {
		// https://developer.authorize.net/api/reference/index.html#payment-transactions-authorize-a-credit-card
		
		var requestBody = [
			"createTransactionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"transactionRequest" = [
					"transactionType" = "authCaptureTransaction",		
					"amount" = arguments.amount,
					"currencyCode" = "USD",
					"payment" = [
						"creditCard" = [
							"cardNumber" = arguments.ccNumber,
							"expirationDate" = arguments.ccExp,
							"cardCode" = arguments.ccCvv2
						]
					],
					"customer" = [
						"id" = arguments.customerId,
						"email" = arguments.email
					],
					"billTo" = [
						"firstName" = arguments.ccFirstName,
						"lastName" = arguments.ccLastName,
						"company" = arguments.ccCompany,
						"address" = arguments.ccAddress,
						"city" = arguments.ccCity,
						"state" = arguments.ccState,
						"zip" = arguments.ccZipcode,
						"country" = arguments.ccCountry
					],
					"customerIP" = arguments.customerIP,
					"processingOptions" = [
						"isFirstRecurringPayment" = arguments.isFirstRecurringPayment,
						"isFirstSubsequentAuth" = arguments.isFirstSubsequentAuth,
						"isSubsequentAuth" = arguments.isSubsequentAuth,
						"isStoredCredentials" = arguments.isStoredCredentials
					],			
					"authorizationIndicatorType" = [
						"authorizationIndicator" = "final"
					]
				]			
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), userId = arguments.userId, subscriptionId = arguments.subscriptionId );
	}


	struct function void(
		required refTransId,
		userId = "",
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#payment-transactions-void-a-transaction
		// can be used on an auth or capture transaction
		
		var requestBody = [
			"createTransactionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"transactionRequest" = [
					"transactionType": "voidTransaction",
					"refTransId": arguments.refTransId
				]			
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), subscriptionId = arguments.subscriptionId );
	}

	
	struct function refundTransaction(
		required refTransId,
		required cardLast4,
		required amount,
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#payment-transactions-refund-a-transaction
	
		var requestBody = [
			"createTransactionRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
					"transactionRequest" = [
					"transactionType" = "refundTransaction",
					"amount" = "5.00",
					"payment" = [
						"creditCard" = [
							"cardNumber" = arguments.cardLast4,
							"expirationDate" = "XXXX"
						]
					],
					"refTransId" = arguments.refTransId
				]
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), userId = arguments.userId, subscriptionId = arguments.subscriptionId );
	}
	
	
	struct function getTransactionDetails(
		required transId,
		userId = "",
		subscriptionId = ""
	) {
		// https://developer.authorize.net/api/reference/index.html#transaction-reporting-get-transaction-details
		
		var requestBody = [
			"getTransactionDetailsRequest" = [
				"merchantAuthentication" = [
					"name" = variables.apilogin,
					"transactionKey" = variables.transkey
				],
				"transId" = arguments.transId
			]
		];
		
		return sendRequest(body = serializeJSON(requestBody), userId = arguments.userId, subscriptionId = arguments.subscriptionId );
	}

	
	struct function sendRequest(
		string method = "POST",
		string contentType = "application/json",
		array extraheaders = [],
		string body = "",
		userId = "",
		string subscriptionId = ""
	) {
		try {		
			var server_response = "";
			
			cfhttp(
				method = arguments.method, 
				url = variables.endpoint,
				result = "server_response"
			) {
				cfhttpparam( type="header", name="Content-Type", value= arguments.contentType);
				for( var param in arguments.extraheaders ) {
					cfhttpparam( type="header", name = param.name, value = param.value );
				}
				 
				if( arguments.body != '' ) {
					cfhttpparam( type="body", value=arguments.body);
				}
			}
			
			//writedump(server_response);
			
			logRequest(
				path = endpoint,
				method = arguments.method,
				body = arguments.body,
				statusCode = server_response.statusCode,
				errorDetail = isDefined("server_response.ErrorDetail") ? server_response.ErrorDetail : "",
				responseContent = isDefined("server_response.filecontent") ? server_response.filecontent : '',
				userId = arguments.userId,
				subscriptionId = arguments.subscriptionId
			);	
			
			if( FindNoCase("Connection Failure", server_response.statusCode) ) {
				throw (type = "authorizedotnet.request", errorCode = "Connection Error", message = server_response.ErrorDetail );
			}			
			else if( FindNoCase("Request Time-out", server_response.StatusCode) ) {
				throw (type = "authorizedotnet.request", errorCode = "Request Time-out", message = server_response.ErrorDetail );
			}			
			
			if( server_response.status_code == '200' ) {
				// need to remove this BOM special character at beginning of filecontent
				server_response.filecontent = Left( server_response.filecontent, 1 ) == chr(65279) ? mid(server_response.filecontent, 2, len(server_response.filecontent)) : server_response.filecontent;

				if( arguments.contentType == 'application/json' ) {
					//writedump(server_response.filecontent);
					return deserializeJSON( server_response.filecontent );
				}
				else {
					return deserializeJSON( variables.xmlToJsonObj.toJSONObject( server_response.fileContent, true) );
				}
			}
			else {
				throw (type = "authorizedotnet.request", errorCode = server_response.status_code, message = server_response.errordetail, detail = server_response.filecontent );
			}
			
		}
		catch( any e ) {
                        //  Add you own handling here.  
			//variables.exceptionsLib.handleException(exception=e);
			//cfrethrow();
		}
	}

	
	//----------------------------------- request logging functions -------------------------------------------------------------------------------------------
	
	
	void function logRequest(
		required path,
		required method,
		body = "",
		statusCode = "",
		errorDetail = "",
		responseContent = "",
		userId = "",
		subscriptionId = ""
	) {
	
		// strip card number and security code from body
		var strippedBody = rereplace( arguments.body, '\"cardCode\"\:\"[a-z0-9]*\"', '"cardCode":"xxx"');
		strippedBody = rereplace( strippedBody, '\"cardNumber\"\:\"[0-9]{12}([0-9]{4})\"', '"cardNumber":"xxxx-xxxx-xxxx-\1"');

		try {
			queryExecute(	
				"INSERT INTO paymentGatewayRequests ( 
					requestId,
					requestDate,
					path,
					method,
					body,
					statusCode,
					errorDetail,
					responseContent,
					userId,
					subscriptionId
				)
				VALUES (
					:requestId,
					:requestDate,
					:path,
					:method,
					:body,
					:statusCode,
					:errorDetail,
					:responseContent,
					:userId,
					:subscriptionId
				 )",
				{
					requestId = { value = CreateUUID(), cfsqltype = "cf_sql_varchar" },
					requestDate = { value = CreateODBCDateTime(Now()), cfsqltype = "cf_sql_timestamp" },
					path = { value = arguments.path, cfsqltype = "cf_sql_varchar" },
					method = { value = arguments.method, cfsqltype = "cf_sql_varchar" },
					body = { value = strippedBody, cfsqltype = "cf_sql_varchar" },
					statusCode = { value = arguments.statusCode, cfsqltype = "cf_sql_varchar" },
					errorDetail = { value = arguments.errorDetail, cfsqltype = "cf_sql_varchar" },
					responseContent = { value = arguments.responseContent, cfsqltype = "cf_sql_varchar" },
					userId = { value = arguments.userId, cfsqltype = "cf_sql_varchar" },
					subscriptionId = { value = arguments.subscriptionId, cfsqltype = "cf_sql_varchar" }
				},
				{ datasource = variables.ds }	
			);			
		}
		catch( any e ) {
			writedump(e);
		}
		
		return;
	}

}
