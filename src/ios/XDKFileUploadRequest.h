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

//
// XDKFileUploadRequest.h
// This file is added to the LFWebAPIKit

extern NSString *const XDKFileUploadRequestErrorDomain;

enum {
    XDKFileUploadRequestConnectionError = 0x7fff0001,
    XDKFileUploadRequestTimeoutError = 0x7fff0002,    
	XDKFileUploadRequestFaultyXMLResponseError = 0x7fff0003,
    XDKFileUploadRequestUnknownError = 0x7fff0042
};


@class XDKFileUploadRequest;


@protocol XDKFileUploadRequestDelegate <NSObject>
@optional

- (void)FileUploadRequest:(XDKFileUploadRequest *)inRequest
  didCompleteWithResponse:(NSDictionary *)inResponseDictionary;

- (void)FileUploadRequest:(XDKFileUploadRequest *)inRequest
         didFailWithError:(NSError *)inError;

- (void)FileUploadRequest:(XDKFileUploadRequest *)inRequest
      fileUploadSentBytes:(NSUInteger)inSentBytes
               totalBytes:(NSUInteger)inTotalBytes;

@end


@interface XDKFileUploadRequest : NSObject

- (id) init;
- (BOOL) uploadFileStream:(NSInputStream *)inFileStream
        suggestedFilename:(NSString *)inFilename
      suggestedFoldername:(NSString *)inFoldername
                 MIMEType:(NSString *)inType
               toEndPoint:(NSString *) uploadEndpoint;
- (BOOL) isRunning;
- (void) cancel;
- (NSTimeInterval) requestTimeoutInterval;
- (void) setRequestTimeoutInterval:(NSTimeInterval)inTimeInterval;

@property (nonatomic, weak) id<XDKFileUploadRequestDelegate> delegate;
@property (nonatomic) id sessionInfo;
@end
