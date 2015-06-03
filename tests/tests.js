/*
Copyright 2015 Intel Corporation

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file 
except in compliance with the License. You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the 
License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
either express or implied. See the License for the specific language governing permissions 
and limitations under the License
*/

/*global exports, describe, it, xit, expect, intel, console, document, Windows*/
exports.defineAutoTests = function () {
    'use strict';
    
    describe("intel.xdk.file tests", function () {
        it("check that exists", function () {
            expect(intel.xdk.file).toBeDefined();
        });
        
        it("should have an uploadToServer method", function () {
            expect(intel.xdk.file.uploadToServer).toBeDefined();
            expect(typeof intel.xdk.file.uploadToServer).toEqual('function');
        });
        
        it("should have a cancelUpload method", function () {
            expect(intel.xdk.file.cancelUpload).toBeDefined();
            expect(typeof intel.xdk.file.cancelUpload).toEqual('function');
        });
    });
};

exports.defineManualTests = function (contentEl, createActionButton) {
    'use strict';
    
    /** object to hold properties and configs */
    var FileTestSuite = {};
    
    function logMessage(message, color) {
        var log = document.getElementById('info'),
            logLine = document.createElement('div');
        
        if (color) {
            logLine.style.color = color;
        }
        
        logLine.innerHTML = message;
        log.appendChild(logLine);
    }

    function clearLog() {
        var log = document.getElementById('info');
        log.innerHTML = '';
    }
    
    function testNotImplemented(testName) {
        return function () {
            console.error(testName, 'test not implemented');
        };
    }
    
    function updateUploadProgress(bytesSent,totalBytes){
        var currentProgress = totalBytes>0? (bytesSent/totalBytes)*100 : -1;
        console.log('progress:', currentProgress + '%');
    }
    
    function init() {
        document.addEventListener('intel.xdk.file.upload.busy', function(evt){
            console.log('event:',evt.type);
            console.error('Sorry, a file is already being uploaded');
        });
        
        document.addEventListener('intel.xdk.file.upload', function(evt){
            console.log('event:',evt.type);
            if(evt.success === true){
                console.log('File', evt.localURL, 'was uploaded');
            } else {
                console.error('Error uploading file:', evt.message);
            }
        });
        
        document.addEventListener('intel.xdk.file.upload.cancel', function(evt){
            console.log('event:',evt.type);
            console.log("File upload was cancelled:",evt.localURL);
        });
        
        document.addEventListener('intel.xdk.camera.picture.add', function(evt){
            console.log('event:',evt.type);
            var pictureList = intel.xdk.camera.getPictureList();
            if(pictureList.length > 0){
                var pictureURL = intel.xdk.camera.getPictureURL(pictureList[pictureList.length-1]);
                intel.xdk.file.uploadToServer(pictureURL, FileTestSuite.UPLOAD_URL, "", "image/jpeg", "updateUploadProgress");
            }
        });
        
        logMessage(JSON.stringify('Will upload to ' + FileTestSuite.UPLOAD_URL, null, '\t'),'green');
    }
    
    FileTestSuite.UPLOAD_URL = "http://www.johnphughes.net/apiTesting/apiTestingUpload.php";
    
    FileTestSuite.$markup = '<h3>Upload to Server</h3>' +
        '<div id="buttonUpload"></div>' +
        'Expected result: should take a picture, then upload it to the server' +
        '<div id="buttonCancelUpload"></div>' +
        'Expected result: should cancel current upload' +
        
        '<h3>WINDOWS - Upload to Server</h3>' +
        '<div id="buttonUploadToServer"></div>' +
        'Expected result: on Windows, sould upload a picture to the server' +
        '';
    
        
    contentEl.innerHTML = '<div id="info"></div>' + FileTestSuite.$markup;
    
    createActionButton('takePicture()', function () {
        console.log('executing::intel.xdk.camera.takePicture');
        intel.xdk.camera.takePicture(50, false, 'jpg');
    }, 'buttonUpload');
    
    createActionButton('cancelUpload()', function () {
        console.log('executing::intel.xdk.file.cancelUpload');
        intel.xdk.file.cancelUpload();
    }, 'buttonCancelUpload');
    
    createActionButton('uploadToServer()', function () {
        console.log('executing::intel.xdk.file.uploadToServer');
        
        Windows.Storage.KnownFolders.picturesLibrary.getFilesAsync()
        .done(function(files) {
            if (files !== null) {
                var localURL = files[Math.floor((Math.random() * files.length-1) + 1)].path;
                var uploadServer = FileTestSuite.UPLOAD_URL;
                var folderName = 'PictruesLibrary';
                var mimeType = 'image/jpg';
                var success = 'uploadSuccess';

                intel.xdk.file.uploadToServer(localURL, uploadServer, folderName, mimeType, updateUploadProgress);
            }
        }, function(e){
            console.error(e);
        });
        
    }, 'buttonUploadToServer');
    
    document.addEventListener('deviceready', init, false);
    
};