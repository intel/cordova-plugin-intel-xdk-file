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


// This try/catch is temporary to maintain backwards compatibility. Will be removed and changed to just 
// require('cordova/exec/proxy') at unknown date/time.
var commandProxy;
try {
    commandProxy = require('cordova/windows8/commandProxy');
} catch (e) {
    commandProxy = require('cordova/exec/proxy');
}

module.exports = {
    upload : null,
    promise : null,
    fileExtension: "ms-appdata:///local",

    uploadToServer:function(success, error, args){
        var localURL = args[0];
        var uploadURL = args[1];
        var folderName = args[2];
        var mimeType = args[3];
        var uploadProgressCallback = args[4];

        var me = module.exports;

        // point to the file with the full path.
        if (localURL.indexOf("ms-appdata") != -1) {
            localURL = Windows.Storage.ApplicationData.current.localFolder.path + "\\" + localURL.replace(me.pictureExtension, "").replace("/", "\\");
        }

        Windows.Storage.StorageFile.getFileFromPathAsync(localURL).done(
            function success(file) {
                module.exports.upload = new UploadOp();
                module.exports.promise = module.exports.upload.start(uploadURL, file, folderName, mimeType);
            },
            function error() {
                alert('in here 2');
            });

        function UploadOp() {
            var me = module.exports;
            var upload = null;
            var promise = null;

            this.start = function (uriString, file, folderName, mimeType) {
                try {

                    var uri = new Windows.Foundation.Uri(uriString);
                    var uploader = new Windows.Networking.BackgroundTransfer.BackgroundUploader();

                    // Set a header, so the server can save the file (this is specific to the sample server).
                    uploader.setRequestHeader("Filename", file.name);
                    uploader.setRequestHeader('FolderName', folderName);
                    uploader.setRequestHeader('Content-Type', mimeType);

                    // Create a new upload operation.
                    upload = uploader.createUpload(uri, file);

                    // Start the upload and persist the promise to be able to cancel the upload.
                    promise = upload.startAsync().then(
                        function () {
                            /*var e = document.createEvent('Events');
                            e.initEvent('intel.xdk.file.upload', true, true);
                            e.success = true;
                            e.localURL = localURL;
                            document.dispatchEvent(e);*/
                            me.createAndDispatchEvent("intel.xdk.file.upload",
                                {
                                    success: true,
                                    localURL: localURL
                                });

                            //                  //Success callback.
                            //window[uploadProgressCallback]();
                        }, function (err) {
                            /*var e = document.createEvent('Events');
                            e.initEvent('intel.xdk.file.upload.cancel', true, true);
                            e.success = true;
                            e.localURL = localURL;
                            document.dispatchEvent(e);*/
                            me.createAndDispatchEvent("intel.xdk.file.upload.cancel",
                                {
                                    success: true,
                                    localURL: localURL
                                });
                        }, function () {
                            var currentProgress = upload.progress;
                            uploadProgressCallback(currentProgress.bytesSent, currentProgress.totalBytesToSend);
                        });
                } catch (err) {
                    console.log(err);
                }
            };

            this.startMultipart = function (uri, files) {
                alert('in here');
            }
        }
    },

    cancelUpload:function(){
        /*module.exports.promise.cancel();
        var e = document.createEvent('Events');
        e.initEvent('intel.xdk.file.upload.cancel', true, true);
        e.success = true;
        e.localURL = localURL;
        document.dispatchEvent(e);*/
        var me = module.exports;
        me.promise.cancel();
        me.createAndDispatchEvent("intel.xdk.file.upload.cancel",
            {
                success: true,
                localURL: localURL
            });
    },

    createAndDispatchEvent: function (name, properties) {
        var e = document.createEvent('Events');
        e.initEvent(name, true, true);
        if (typeof properties === 'object') {
            for (key in properties) {
                e[key] = properties[key];
            }
        }
        document.dispatchEvent(e);
    }
};



commandProxy.add('IntelXDKFile', module.exports);
