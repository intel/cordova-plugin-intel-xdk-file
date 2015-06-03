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
// XDKFileUploadRequest
// This file is added to the LFWebAPIKit

#import "XDKFileUploadRequest.h"
#import "LFWebAPIKit.h"


NSString *const XDKFileUploadTempFilenamePrefix = @"com.intel.xdk.upload";
NSString *const XDKFileUploadRequestErrorDomain = @"com.intel.xdk.upload";


@implementation XDKFileUploadRequest
{
    LFHTTPRequest *HTTPRequest;    
    NSString *uploadTempFilename;
}


- (void)dealloc
{
    [self cleanUpTempFile];
}

- (id)init
{
    if ((self = [super init])) {
        HTTPRequest = [LFHTTPRequest new];
        [HTTPRequest setDelegate:self];
    }
    return self;
}


- (NSTimeInterval) requestTimeoutInterval
{
    return [HTTPRequest timeoutInterval];
}

- (void) setRequestTimeoutInterval:(NSTimeInterval) inTimeoutInterval
{
    [HTTPRequest setTimeoutInterval:inTimeoutInterval];
}

- (BOOL) isRunning
{
    return [HTTPRequest isRunning];
}

- (void) cancel
{
    [HTTPRequest cancelWithoutDelegateMessage];
    [self cleanUpTempFile];
}


- (BOOL) uploadFileStream:(NSInputStream *)inFileStream suggestedFilename:(NSString *)inFilename suggestedFoldername:(NSString *)inFoldername MIMEType:(NSString *)inType toEndPoint:(NSString *) uploadEndpoint
{
    if ([HTTPRequest isRunning]) {
        return NO;
    }

    NSString *separator = GenerateUUIDString();
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", separator];
    
    // build the multipart form
    NSMutableString *multipartBegin = [NSMutableString string];
    NSMutableString *multipartEnd = [NSMutableString string];

	[multipartBegin appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"Filename\"\r\n\r\n%@\r\n", separator, [inFilename length] ? inFilename : GenerateUUIDString()];
	if(inFoldername != nil)
		[multipartBegin appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"folder\"\r\n\r\n%@\r\n", separator, inFoldername];
	[multipartBegin appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"Filedata\"; filename=\"%@\"\r\n", separator, [inFilename length] ? inFilename : GenerateUUIDString()];
    [multipartBegin appendFormat:@"Content-Type: %@\r\n\r\n", inType];
    [multipartEnd appendFormat:@"\r\n--%@--", separator];

    // create/clean a temp file
    [self cleanUpTempFile];
    uploadTempFilename = [NSTemporaryDirectory() stringByAppendingFormat:@"%@.%@", XDKFileUploadTempFilenamePrefix, GenerateUUIDString()];
    
    // create the write stream
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:uploadTempFilename append:NO];
    [outputStream open];
    
    const char *UTF8String;
    size_t writeLength;
    UTF8String = [multipartBegin UTF8String];
    writeLength = strlen(UTF8String);
	
	size_t __unused actualWrittenLength;
	actualWrittenLength = [outputStream write:(uint8_t *)UTF8String maxLength:writeLength];
    NSAssert(actualWrittenLength == writeLength, @"Must write multipartBegin");
	
    // open the input stream
    const size_t bufferSize = 65536;
    size_t readSize = 0;
    uint8_t *buffer = (uint8_t *)calloc(1, bufferSize);
    NSAssert(buffer, @"Must have enough memory for copy buffer");
	
    [inFileStream open];
    while ([inFileStream hasBytesAvailable]) {
        if (!(readSize = [inFileStream read:buffer maxLength:bufferSize])) {
            break;
        }
		size_t __unused actualWrittenLength;
		actualWrittenLength = [outputStream write:buffer maxLength:readSize];
        NSAssert (actualWrittenLength == readSize, @"Must completes the writing");
    }
    
    [inFileStream close];
    free(buffer);
    
    UTF8String = [multipartEnd UTF8String];
    writeLength = strlen(UTF8String);
	actualWrittenLength = [outputStream write:(uint8_t *)UTF8String maxLength:writeLength];
    NSAssert(actualWrittenLength == writeLength, @"Must write multipartBegin");
    [outputStream close];
    
    NSError *error = nil;
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:uploadTempFilename error:&error];
    NSAssert(fileInfo && !error, @"Must have upload temp file");

    NSNumber *fileSizeNumber = fileInfo[NSFileSize];
    NSUInteger fileSize = 0;
	
    if ([fileSizeNumber respondsToSelector:@selector(integerValue)]) {
        fileSize = [fileSizeNumber integerValue];                    
    }
    else {
        fileSize = [fileSizeNumber intValue];                    
    }                
    
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:uploadTempFilename];
	
    [HTTPRequest setContentType:contentType];
    return [HTTPRequest performMethod:LFHTTPRequestPOSTMethod
                                onURL:[NSURL URLWithString:uploadEndpoint]
                      withInputStream:inputStream
                     knownContentSize:fileSize];
}


#pragma mark LFHTTPRequest delegate methods

- (void)httpRequestDidComplete:(LFHTTPRequest *)request
{
	// Currently does not process the html response, if needed can parse the XML or just pass [request receivedData] to the caller
	NSDictionary *rsp = @{ @"status": @"Uploading done!" };

    [self cleanUpTempFile];
    if ([self.delegate respondsToSelector:@selector(FileUploadRequest:didCompleteWithResponse:)]) {
		[self.delegate FileUploadRequest:self didCompleteWithResponse:rsp];
    }    
}


- (void)httpRequest:(LFHTTPRequest *)request
   didFailWithError:(NSString *)error
{
    NSError *toDelegateError;
    if ([error isEqualToString:LFHTTPRequestConnectionError]) {
		toDelegateError = [NSError errorWithDomain:XDKFileUploadRequestErrorDomain
                                              code:XDKFileUploadRequestConnectionError
                                          userInfo:@{ NSLocalizedFailureReasonErrorKey:
                                                          @"Network connection error" }];
    }
    else if ([error isEqualToString:LFHTTPRequestTimeoutError]) {
		toDelegateError = [NSError errorWithDomain:XDKFileUploadRequestErrorDomain
                                              code:XDKFileUploadRequestTimeoutError
                                          userInfo:@{ NSLocalizedFailureReasonErrorKey:
                                                          @"Request timeout" }];
    }
    else {
		toDelegateError = [NSError errorWithDomain:XDKFileUploadRequestErrorDomain
                                              code:XDKFileUploadRequestUnknownError
                                          userInfo:@{ NSLocalizedFailureReasonErrorKey:
                                                          @"Unknown error" }];
    }
    
    [self cleanUpTempFile];
    if ([self.delegate respondsToSelector:@selector(FileUploadRequest:didFailWithError:)]) {
        [self.delegate FileUploadRequest:self didFailWithError:toDelegateError];
    }
}

- (void)httpRequest:(LFHTTPRequest *)request
          sentBytes:(NSUInteger)bytesSent
              total:(NSUInteger)total
{
    if (uploadTempFilename &&
        [self.delegate respondsToSelector:
         @selector(FileUploadRequest:fileUploadSentBytes:totalBytes:)])
    {
        [self.delegate FileUploadRequest:self fileUploadSentBytes:bytesSent totalBytes:total];
    }
}


#pragma mark Private Methods

NSString *GenerateUUIDString()
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    NSString* uuidStr = (__bridge_transfer NSString*) CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
	return uuidStr;
}

- (void)cleanUpTempFile
{
    if (uploadTempFilename) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:uploadTempFilename]) {
			BOOL __unused removeResult = NO;
			NSError *error = nil;
			removeResult = [fileManager removeItemAtPath:uploadTempFilename error:&error];
			NSAssert(removeResult, @"Should be able to remove temp file");
        }
        uploadTempFilename = nil;
    }
}

@end
