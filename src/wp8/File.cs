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

using Microsoft.Xna.Framework.Media;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using Windows.Storage;
using WPCordovaClassLib.Cordova;
using WPCordovaClassLib.Cordova.Commands;
using WPCordovaClassLib.Cordova.JSON;

namespace Cordova.Extension.Commands
{
    class IntelXDKFile : BaseCommand
    {
        const int BLOCK_SIZE = 4096;
        private byte[] buffer;
        private HttpWebRequest httpWebRequest = null;
        private bool uploading;
        private string fileUpload;
        private string updateCallback;
        private long fileSize;

        public IntelXDKFile()
        {
        }

        public void uploadToServer(string parameters)
        {
            UpoadFile(parameters);
        }

        public void cancelUpload(String args)
        {
            if (uploading && httpWebRequest != null)
            {
                httpWebRequest.Abort();
            }
        }

        #region Private Methods
        private async void UpoadFile(string parameters)
        {
            if (uploading)
            {
                string js = "var e = document.createEvent('Events');" +
                    "e.initEvent('intel.xdk.file.upload.busy',true,true);" +
                    "e.success=false;e.message='busy';document.dispatchEvent(e);";
                InvokeCustomScript(new ScriptCallback("eval", new string[] { js }), true);
                return;
            }

            string[] args = WPCordovaClassLib.Cordova.JSON.JsonHelper.Deserialize<string[]>(parameters);

            string localURL = args[0];
            string uploadURL = args[1];
            string folderName = args[2];
            string mimeType = args[3];
            string uploadProgressCallback = args[4];

            if (localURL == null || localURL.Length == 0)
            {
                callJSwithError("Missing filename parameter.");
                return;
            }

            updateCallback = (uploadProgressCallback != null && uploadProgressCallback.Length > 0) ? uploadProgressCallback : null;

            fileUpload = localURL;

            uploading = true;

            FileStream file = System.IO.File.OpenRead(localURL);
            fileSize = file.Length;

            byte[] fileBytes = new byte[file.Length];
            for (int i = 0; i < fileBytes.Length; i++)
            {
                fileBytes[i] = (byte)file.ReadByte();
            }

            var Params = new Dictionary<string, string>();

            string boundary = "----------" + DateTime.Now.Ticks.ToString("x");
            httpWebRequest = (HttpWebRequest)WebRequest.Create(new Uri(uploadURL));
            httpWebRequest.ContentType = "multipart/form-data; boundary=" + boundary;
            httpWebRequest.Method = "POST";

            httpWebRequest.BeginGetRequestStream((result) =>
            {
                try
                {
                    notifyBytesSent(0, fileSize);

                    HttpWebRequest request = (HttpWebRequest)result.AsyncState;
                    using (Stream requestStream = request.EndGetRequestStream(result))
                    {
                        WriteMultipartForm(requestStream, boundary, Params, Path.GetFileName(localURL), mimeType, fileBytes, folderName);
                    }

                    request.BeginGetResponse(a =>
                    {
                        try
                        {
                            var response = request.EndGetResponse(a);
                            var responseStream = response.GetResponseStream();
                            using (var sr = new StreamReader(responseStream))
                            {
                                using (StreamReader streamReader = new StreamReader(response.GetResponseStream()))
                                {
                                    string responseString = streamReader.ReadToEnd();
                                    uploading = false;
                                    notifyBytesSent(fileSize, fileSize);

                                    notifySuccess();
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            uploading = false;
                            callJSwithError(string.Format("Cannot upload the file '{0}' for upload!", localURL));
                        }
                    }, null);
                }
                catch (Exception)
                {
                    uploading = false;
                    callJSwithError(string.Format("Cannot upload the file '{0}' for upload!", localURL));
                }
            }, httpWebRequest);
        }

        private void ReadCallback(IAsyncResult asynchronousResult)
        {
            //try
            //{
            //    HttpWebRequest request = (HttpWebRequest)asynchronousResult.AsyncState;
            //    // End the operation.            
            //    Stream postStream = request.EndGetRequestStream(asynchronousResult);
            //    postStream.Write(requestState.headerBytes, 0, requestState.headerBytes.Length);
            //    postStream.Write(buffer, 0, buffer.Length);
            //    postStream.Write(requestState.footerBytes, 0, requestState.footerBytes.Length);
            //    postStream.Close();
            //    request.BeginGetResponse(new AsyncCallback(ResponseCallback), request);
            //}
            //catch (Exception ex)
            //{
            //    // TODO: Handle exception.
            //}
        }

        private void ResponseCallback(IAsyncResult asynchronousResult)
        {
            //HttpWebRequest request = (HttpWebRequest)asynchronousResult.AsyncState;
            //HttpWebResponse resp = (HttpWebResponse)request.EndGetResponse(asynchronousResult);
            //Stream streamResponse = resp.GetResponseStream();
            //StreamReader streamRead = new StreamReader(streamResponse);
            //string responseString = streamRead.ReadToEnd();
            ////Dispatcher.BeginInvoke(new Action(() => { MessageBox.Show(responseString); }));
            //// Close the stream object.            
            //streamResponse.Close();
            //streamRead.Close();
            //// Release the HttpWebResponse.            
            //resp.Close();
        }
        #endregion


        #region FROM SO
        // http://stackoverflow.com/questions/19954287/how-to-upload-file-to-server-with-http-post-multipart-form-data
        /// <summary>
        /// Writes multi part HTTP POST request. Author : Farhan Ghumra
        /// </summary>
        private void WriteMultipartForm(Stream s, string boundary, Dictionary<string, string> data, string fileName, string fileContentType, byte[] fileData, string folderName)
        {
            /// The first boundary
            byte[] boundarybytes = Encoding.UTF8.GetBytes("--" + boundary + "\r\n");
            /// the last boundary.
            byte[] trailer = Encoding.UTF8.GetBytes("\r\n--" + boundary + "–-\r\n");
            /// the form data, properly formatted
            string formdataTemplate = "Content-Disposition: form-data; name=\"{0}\"\r\n\r\n{1}";
            /// the form-data file upload, properly formatted
            string fileheaderTemplate = "Content-Disposition: form-data; name=\"{0}\"; filename=\"{1}\";\r\nContent-Type: {2}\r\n\r\n";

            /// Added to track if we need a CRLF or not.
            bool bNeedsCRLF = false;

            if (data != null)
            {
                foreach (string key in data.Keys)
                {
                    /// if we need to drop a CRLF, do that.
                    if (bNeedsCRLF)
                        WriteToStream(s, "\r\n");

                    /// Write the boundary.
                    WriteToStream(s, boundarybytes);

                    /// Write the key.
                    WriteToStream(s, string.Format(formdataTemplate, key, data[key]));
                    bNeedsCRLF = true;
                }
            }

            /// If we don't have keys, we don't need a crlf.
            if (bNeedsCRLF)
                WriteToStream(s, "\r\n");

            WriteToStream(s, String.Format("--{0}\r\nContent-Disposition: form-data; " +
                        "name=\"Filename\"\r\n\r\n{1}\r\n", boundary, fileName));
            WriteToStream(s, String.Format("--{0}\r\nContent-Disposition: form-data; " +
                    "name=\"folder\"\r\n\r\n{1}\r\n", boundary, folderName));
            WriteToStream(s, String.Format("--{0}\r\nContent-Disposition: form-data; " +
                    "name=\"Filedata\"; filename=\"{1}\"\r\n", boundary, fileName));
            WriteToStream(s, String.Format("Content-Type: {0}\r\n\r\n", fileContentType));
            /// Write the file data to the stream.
            WriteToStream(s, fileData);
            WriteToStream(s, trailer);
        }

        /// <summary>
        /// Writes string to stream. Author : Farhan Ghumra
        /// </summary>
        private void WriteToStream(Stream s, string txt)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(txt);
            s.Write(bytes, 0, bytes.Length);
        }

        /// <summary>
        /// Writes byte array to stream. Author : Farhan Ghumra
        /// </summary>
        private void WriteToStream(Stream s, byte[] bytes)
        {
            s.Write(bytes, 0, bytes.Length);
        }

        private void notifySuccess()
        {
            string js = String.Format("var e = document.createEvent('Events');" +
                    "e.initEvent('intel.xdk.file.upload',true,true);e.success=true;" +
                    "e.localURL='{0}';document.dispatchEvent(e);", fileUpload);
            InvokeCustomScript(new ScriptCallback("eval", new string[] { js }), true);
        }
        private void notifyCancelled()
        {
            string js = String.Format("var e = document.createEvent('Events');" +
                    "e.initEvent('intel.xdk.file.upload.cancel',true,true);e.success=true;" +
                    "e.localURL='{0}';document.dispatchEvent(e);", fileUpload);
            InvokeCustomScript(new ScriptCallback("eval", new string[] { js }), true);
        }
        private void notifyBytesSent(long sentBytes, long totalBytes)
        {
            if (updateCallback != null)
            {
                string js = String.Format("javascript:{0}({1}, {2});", updateCallback, sentBytes, totalBytes);
                InvokeCustomScript(new ScriptCallback("eval", new string[] { js }), false);
            }
        }

        private void callJSwithError(string msg)
        {
            string tempString = msg.Replace('"', '\'');
            string js = String.Format("var e = document.createEvent('Events');" +
                    "e.initEvent('intel.xdk.file.upload',true,true);e.success=false;" +
                    "e.message='{0}';document.dispatchEvent(e);", tempString);
            InvokeCustomScript(new ScriptCallback("eval", new string[] { js }), true);
        }
        #endregion
    }
}