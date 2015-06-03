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

package com.intel.xdk.file;

import java.io.DataOutputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.UUID;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;


import android.app.Activity;

public class File extends CordovaPlugin{
	public static boolean debug = false;
	private UpLoader uploader;
	private boolean uploading;
	private String fileUpload;
	private String updateCallback;
	
	private Activity activity;
	private CordovaWebView webView;
	
	private class UpLoader extends Thread {
		private byte data[];//++++++Change this to an inputstream in case it's large.
		String baseName, folderName, mime, uploadUrl;
		public UpLoader(byte buf[], String base, String folder, String mimet, String upload) {
			super("Uploader:constructor");
			data = buf; baseName = base; folderName = folder; mime = mimet; uploadUrl = upload;
		}
		@Override
    	public void run() {
			String lineEnd = "\r\n";
			String twoHyphens = "--";
			UUID uuid = UUID.randomUUID();
			String boundary = uuid.toString();
			HttpURLConnection connection = null;
			DataOutputStream outputStream;
			Boolean failed = false, interrupted = false;
			
			try {
				URL url = new URL(uploadUrl);
				connection = (HttpURLConnection) url.openConnection();

				// Allow Inputs & Outputs
				connection.setDoInput(true);
				connection.setDoOutput(true);
				connection.setUseCaches(false);

				// Enable POST method
				connection.setRequestMethod("POST");
				connection.setRequestProperty("Connection", "Keep-Alive");
				connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" +
																	boundary);

				outputStream = new DataOutputStream(connection.getOutputStream());
				System.out.println("I'm here");
				outputStream.writeBytes(twoHyphens + boundary + lineEnd);
				
				if (debug)
					System.out.println("AppMobiFile: Sending file of size " + data.length +
							" to '" + uploadUrl +
							"', remote file: " + folderName + " folder: " + baseName);
				outputStream.writeBytes(String.format("--%1$s\r\nContent-Disposition: form-data; " +
						"name=\"Filename\"\r\n\r\n%2$s\r\n", boundary, baseName));
				outputStream.writeBytes(String.format("--%1$s\r\nContent-Disposition: form-data; " +
						"name=\"folder\"\r\n\r\n%2$s\r\n", boundary, folderName));
				outputStream.writeBytes(String.format("--%1$s\r\nContent-Disposition: form-data; " +
						"name=\"Filedata\"; filename=\"%2$s\"\r\n", boundary, baseName));
				outputStream.writeBytes(String.format("Content-Type: %1$s\r\n\r\n", mime));
				int ind = 0, count = data.length;
				final int chunkSize = 0x1000;	// Guessing.
				while (ind < count) {
					if (Thread.interrupted()) {
						interrupted = true;
						break;
					}
					int toWrite = Math.min(chunkSize, count - ind);
					outputStream.write(data, ind, toWrite);
					ind += toWrite;
					notifyBytesSent(ind, count);
				}
				if (!interrupted) {
					outputStream.writeBytes(String.format("\r\n--%1$s--\r\n", boundary));
					outputStream.flush();
					// Responses from the server (code and message)
					int serverResponseCode = connection.getResponseCode();
					String serverResponseMessage = connection.getResponseMessage();
					if (debug)
						System.out.printf("AppMobiFile server response was code %1$d: %2$s\n",
								serverResponseCode, serverResponseMessage);
					
				}
				outputStream.close();
	        } catch (MalformedURLException e) {
	        	callJSwithError(String.format("MalformedURL: " + e.getMessage()));
	            failed = true;
	        } catch (IOException e){
	        	callJSwithError(String.format("Error writing to '%1$s': %2$s", fileUpload, 
						e.getMessage()));
	        	failed = true;
	        }catch (Exception e) {
	        	if (!interrupted) {
	        		callJSwithError(String.format("Error writing to '%1$s': %2$s", fileUpload, 
	        						e.getMessage()));
	        		failed = true;
	        	}
	        }
	        if (!failed) {
	        	if (interrupted)
	        		notifyCancelled();
	        	else
	        		notifySuccess();
	        }
	        uploader = null;
	        uploading = false;
		}
	}
	/**
	 * Constructor
	 */
	public File(){}
	
	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView){
		super.initialize(cordova,webView);
		this.activity = cordova.getActivity();
		this.webView = webView;
	}
	
	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException{
		if(action.equals("uploadToServer")){
			
			String localURL = args.getString(0);
			String uploadURL = args.getString(1);
			String folderName = args.getString(2);
			String mimeType = args.getString(3);
			String uploadProgressCallback = args.getString(4);
			
			this.uploadToServer(localURL, uploadURL , folderName, mimeType, uploadProgressCallback);
		}
		else if(action.equals("cancelUpload")){
			this.cancelUpload();
		}
		else{
			return false;
		}
		return true;
	}
	
	public synchronized void uploadToServer(String url, String uploadUrl, String folderName, String mime, String updateCB){
		if (uploading) {
			String js = "javascript:var e = document.createEvent('Events');" +
				"e.initEvent('intel.xdk.file.upload.busy',true,true);" +
				"e.success=false;e.message='busy';document.dispatchEvent(e);";
			injectJS(js);
			return;
		}
		// file url, should be of format localhost:xxxx/path 
		String filename = null;
		if (url == null || url.length() == 0) {
			callJSwithError("Missing filename parameter.");
			return;
		}
		final String hostPrefix = "localhost:58888/";
		int hostInd = url.indexOf(hostPrefix);
		/*+++++++++++
		if (hostInd == -1) {
			callJSwithError("Filename parameter is not fully qualified.");
			return;
		}
		*/
		if (uploadUrl == null || uploadUrl.length() == 0) {
			callJSwithError("Missing upload URL parameter.");
			return;
		}
		updateCallback = (updateCB != null && updateCB.length() > 0) ? updateCB : null;
		fileUpload = url;
		filename = hostInd >= 0 ? url.substring(hostInd + hostPrefix.length()) : url;
		/*
		String appString = String.format("%1$s/%2$s/", webView.config.appName, 
													webview.config.releaseName);
		int appInd = filename.indexOf(appString);
		if (appInd >= 0) {
			filename = filename.substring(appInd + appString.length());
		}
		*/
		
		//String rootDir = activity.getFilesDir().toString();
		//String path = String.format("%1$s/%2$s", rootDir, filename);  // make full local path
		String path = filename;
		if (mime == null) 
			mime = "text/plain"; // this should not happen since the js puts the default
		java.io.File file = new java.io.File(path);
		if (!file.exists()) {
			callJSwithError(String.format("Cannot find the file '%1$s' for upload!", path));
			return;
		}
		byte data[];
		try {
			FileInputStream in = new FileInputStream(path);
			int len = (int) file.length();
			data = new byte[len];
			in.read(data);
			in.close();
		} catch (IOException e) {
			callJSwithError(String.format("Cannot read the file '%1$s' for upload!", path));
			return;
		}
		String baseName = filename;
		int baseInd = baseName.lastIndexOf('/');
		if (baseInd >= 0) {
			baseName = baseName.substring(baseInd + 1);
		}		
		uploading = true;
		uploader = new UpLoader(data, baseName, folderName, mime, uploadUrl);
		uploader.start();
	}
	
	public void cancelUpload(){
		if (uploading && uploader != null)
			uploader.interrupt();
	}
	
	private void notifySuccess() {
		String js = String.format("javascript:var e = document.createEvent('Events');" +
				"e.initEvent('intel.xdk.file.upload',true,true);e.success=true;" +
				"e.localURL='%1$s';document.dispatchEvent(e);", fileUpload);
		injectJS(js);
	}
	private void notifyCancelled() {
		String js = String.format("javascript:var e = document.createEvent('Events');" +
				"e.initEvent('intel.xdk.file.upload.cancel',true,true);e.success=true;" +
				"e.localURL='%1$s';document.dispatchEvent(e);", fileUpload);
		injectJS(js);
	}
	private void notifyBytesSent(int sentBytes, int totalBytes) {
		if (updateCallback != null) {
			String js = String.format("javascript:%1$s(%2$d, %3$d);", updateCallback, sentBytes, totalBytes);
			injectJS(js);
		}
	}
	private void callJSwithError(String msg) {
		String tempString = msg.replace('"', '\'');
		String js = String.format("javascript:var e = document.createEvent('Events');" +
				"e.initEvent('intel.xdk.file.upload',true,true);e.success=false;" +
				"e.message='%1$s';document.dispatchEvent(e);", tempString);
		injectJS(js);
	}
	protected void injectJS(final String js) {
		activity.runOnUiThread(new Runnable() {

			public void run() {
				webView.loadUrl(js);
			}

		});
	}
}
