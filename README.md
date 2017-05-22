DISCONTINUATION OF PROJECT.  This project will no longer be maintained by Intel.  Intel will not provide or guarantee development of or support for this project, including but not limited to, maintenance, bug fixes, new releases or updates.  Patches to this project are no longer accepted by Intel.  In an effort to support the developer community, Intel has made this project available under the terms of the Apache License, Version 2. If you have an ongoing need to use this project, are interested in independently developing it, or would like to maintain patches for the community, please create your own fork of the project.

intel.xdk.file
==============

For uploading files to an appropriately configured server.

Description
-----------

The file object gives applications the ability to upload files to a remote 
server.

### Methods

-   [cancelUpload](#cancelupload) — This method cancels a previous
    file.uploadToServer command.
-   [uploadToServer](#uploadtoserver) — This method uploads files to a remote
    server over the Internet

### Events


-   [intel.xdk.file.upload](#upload) — Fired once the file.uploadToServer method
    is complete
-   [intel.xdk.file.upload.busy](#uploadbusy) — Fired when accessing the file
    upload is blocked by another process
-   [intel.xdk.file.upload.cancel](#uploadcancel) — Fired if the file upload
    has been interrupted/cancelled

Methods
-------

### cancelUpload

This method cancels a previous [file.uploadToServer](#uploadtoserver)
command.

```javascript
intel.xdk.file.cancelUpload();
```

#### Description

This command may be used to cancel a [file.uploadToServer](#uploadtoserver)
command.

#### Platforms

-   Apple iOS
-   Google Android

#### Example

```javascript
//Get the image to upload
var pictureURL=intel.xdk.camera.getPictureURL(pictureFilename);

intel.xdk.file.uploadToServer(pictureURL,"http://www.yourserver.com/uploadImage.
    php", "", "image/jpeg", "updateUploadProgress");

function updateUploadProgress(bytesSent,totalBytes)
{
   if(totalBytes>0)
        currentProgress=(bytesSent/totalBytes)*100;
   document.getElementById("progress").innerHTML=currentProgress+"%";
}

function cancelUpload()
{
        intel.xdk.file.cancelUpload();
}

document.addEventListener("intel.xdk.file.upload.busy",uploadBusy);
document.addEventListener("intel.xdk.file.upload",uploadComplete);
document.addEventListener("intel.xdk.file.upload.cancel",uploadCancelled);

function uploadBusy(evt)
{
   alert("Sorry, a file is already being uploaded");
}

function uploadComplete(evt)
{
   if(evt.success==true)
   {
      alert("File "+evt.localURL+" was uploaded");
   }
   else {
      alert("Error uploading file "+evt.message);
   }
}

function uploadCancelled(evt)
{
    alert("File upload was cancelled "+evt.localURL);
}
```

### uploadToServer

This method uploads files to a remote server over the Internet

```javascript
intel.xdk.file.uploadToServer(localURL, uploadURL, folderName, mimeType,
    uploadProgressCallback);
```

#### Description

Use this command to upload a file to a server on the Internet.

#### Platforms

-   Apple iOS
-   Google Android

#### Parameters

-   **localURL:** The URL of the file on the local device server. This URL will
    always start with `http://localhost:58888/`.
-   **uploadURL:** The remote server address that the file will be uploaded to
-   **folderName:** The name of the folder on the remote server to hold the
    transferred file
-   **mimeType:** The mime type of the file to be uploaded
-   **uploadProgressCallback:** The function named here is called repetitively
    as the file uploads. The function should include two parameters. The first
    will be the number of bytes sent so far and the second will be the total
    bytes to be uploaded.

#### Example

```javascript
//Get the image to upload
var pictureURL=intel.xdk.camera.getPictureURL(pictureFilename);

intel.xdk.file.uploadToServer(pictureURL,
    "http://www.yourserver.com/uploadImage.php", "", "image/jpeg", 
    "updateUploadProgress");

function updateUploadProgress(bytesSent,totalBytes)
{
   if(totalBytes>0)
        currentProgress=(bytesSent/totalBytes)*100;
   document.getElementById("progress").innerHTML=currentProgress+"%";
}

document.addEventListener("intel.xdk.file.upload.busy",uploadBusy);
document.addEventListener("intel.xdk.file.upload",uploadComplete);
document.addEventListener("intel.xdk.file.upload.cancel",uploadCancelled);

function uploadBusy(evt)
{
   alert("Sorry, a file is already being uploaded");
}

function uploadComplete(evt)
{
   if(evt.success==true)
   {
      alert("File "+evt.localURL+" was uploaded");
   }
   else {
      alert("Error uploading file "+evt.message);
   }
}

function uploadCancelled(evt)
{
    alert("File upload was cancelled "+evt.localURL);
}
```

Events
------

### upload

Fired once the file.uploadToServer method is complete

### upload.busy

Fired when accessing the file upload is blocked by another process

### upload.cancel

Fired if the file upload has been interrupted/cancelled

