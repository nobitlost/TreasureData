// MIT License
//
// Copyright 2018 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

// Internal library constants
const _TREASURE_DATA_SEND_ENDPOINT = "https://in.treasuredata.com";
const _TREASURE_DATA_SEND_PATH = "/postback/v3/event/%s/%s";

// Error details produced by the library
const _TREASURE_DATA_REQUEST_FAILED = "TreasureData request failed with status code";

// This library allows your agent code to send data to the Treasure Data platform
// via the Treasure Data REST API (https://support.treasuredata.com/hc/en-us/articles/360000675487-Postback-API).
class TreasureData {
    static VERSION = "1.0.0";

    _apiKey = null;
    _sendHeaders = null;
    _debug = null;

    // TreasureData class constructor.
    //
    // Parameters:
    //     apiKey : string           Treasure Data API key.
    //                               See https://support.treasuredata.com/hc/en-us/articles/360000763288-Get-API-Keys
    //
    // Returns:                      TreasureData instance created.
    constructor(apiKey) {
        _apiKey = apiKey;
        _sendHeaders = {
            "Content-Type" : "application/json",
            "X-TD-Write-Key" : _apiKey
        };
    }

    // Sends data record to the specified Treasure Data table.
    // See https://support.treasuredata.com/hc/en-us/articles/360000675487-Postback-API#POST%20%2Fpostback%2Fv3%2Fevent%2F%7Bdatabase%7D%2F%7Btable%7D
    //
    // Parameters:
    //     dbName : string           Treasure Data database name.
    //     tableName : string        Treasure Data table name.
    //     data : table              
    //     callback : function       Optional callback function executed once the operation
    //         (optional)            is completed.
    //                               The callback signature:
    //                               callback(error, data), where
    //                                   error : TreasureData.Error  Error details,
    //                                                               or null if the operation succeeds.
    //                                   data : table                The original data passed to 
    //                                                               sendData() method.
    function sendData(dbName, tableName, data, callback = null) {
        _processRequest(
            "POST",
            _TREASURE_DATA_SEND_ENDPOINT,
            format(_TREASURE_DATA_SEND_PATH, dbName, tableName),
            _sendHeaders,
            data,
            function (error) {
                _invokeDefaultCallback(callback, error, data);
            }.bindenv(this));
    }

    // Enables/disables the library debug output (including errors logging).
    // Disabled by default.
    //
    // Parameters:
    //     value : boolean             true to enable, false to disable
    function setDebug(value) {
        _debug = value;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    // Sends an http request to TreasureData.
    function _processRequest(method, endpoint, path, headers, body, callback) {
        local url = endpoint + path;
        local encodedBody = http.jsonencode(body);
        _logDebug(format("Doing the request: %s %s, body: %s", method, url, encodedBody));

        local request = http.request(method, url, headers, encodedBody);
        request.sendasync(function (response) {
            _processResponse(response, callback);
        }.bindenv(this));
    }

    // Processes http response from TreasureData and executes callback.
    function _processResponse(response, callback) {
        _logDebug(format("Response status: %d, body: %s", response.statuscode, response.body));
        local error = null;
        local httpStatus = response.statuscode;
        if (httpStatus < 200 || httpStatus >= 300) {
            local body = null;
            try {
                body = (response.body == "") ? {} : http.jsondecode(response.body);
            } catch (e) {
                _logError(e);
            }
            error = TreasureData.Error(httpStatus, body);
        }
        callback(error);
    }

    // Logs error occurred and invokes callback with default parameters.
    function _invokeDefaultCallback(callback, error, data) {
        if (error) {
            _logError(format("%s: %i", _TREASURE_DATA_REQUEST_FAILED, error.httpStatus));
        }
        if (callback) {
            imp.wakeup(0, function () {
                callback(error, data);
            });
        }
    }

    // Logs error occurred during the library methods execution.
    function _logError(message) {
        if (_debug) {
            server.error("[TreasureData] " + message);
        }
    }

    // Logs debug messages occurred during the library methods execution.
    function _logDebug(message) {
        if (_debug) {
            server.log("[TreasureData] " + message);
        }
    }

    // Auxiliary class, represents error returned by the library in case of HTTP request to Treasure Data failed.
    // The error details can be found in the error.httpStatus and error.httpResponse properties.
    Error = class {
        // HTTP status code (integer)
        httpStatus = null;

        // Response body of the failed request (table)
        httpResponse = null;

        constructor(httpStatus, httpResponse) {
            this.httpStatus = httpStatus;
            this.httpResponse = httpResponse;
        }
    }
}