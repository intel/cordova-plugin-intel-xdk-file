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

#import "XDKFile.h"
#import "XDKFileUploadRequest.h"


// "if(1)" turns OFF XDKog logging.
// "if(0)" turns ON XDKog logging.
#define XDKLog if(0); else NSLog

static NSString * const kXDKUploadStep = @"UploadStep";


@interface XDKFile () <XDKFileUploadRequestDelegate>

@end


@implementation XDKFile
{
    //! An upload request object to be used for all upload requests.
	XDKFileUploadRequest*  _uploadRequest;
    
    //! Flag that indicates "upload in progress". (Only one upload can be active at a time.)
	BOOL                    _uploading;
    
    //! Name of a JavaScript function to be called periodically to report file upload status,
    //! or nil if there is no callback functioon.
	NSString*               _uploadProgressCallback;
    
	//! Local URL parameter for the file to upload.
    NSString*               _localURL;
}

- (void)pluginInitialize
{
	_uploadRequest = [XDKFileUploadRequest new];
	_uploadRequest.delegate = self;
}


#pragma mark - Commands

/*
 Upload a file to a server
 `updateCallback` is optional and is called periodically to show the status of update.
 `localURL` should contain 'localhost:xyz/path/.../filename'.  'filename' portion will be
    extracted and used to name the uploaded file.
 `foldername` namews the folder on the server.  It must be supplied, but may be null.
 `mime` is mime type of the file.  It must be supplied.  If null, default value will be used.
 `uploadURL` is the destination url
 */
- (void) uploadToServer:(CDVInvokedUrlCommand*)command
// (localURL, uploadURL, folderName, mineType, uploadProgressCallback)
{
	if (_uploading || _uploadRequest.sessionInfo) {
        [self fireEvent:@"file.upload.busy" success:NO components:@{ @"message": @"busy" }];
		return;
	}
    _uploading = YES;

    _localURL = [[command argumentAtIndex:0] copy];
	if (!_localURL) {
        [self uploadError:@"LocalURL parameter omitted"];
        return;
    }
    
    NSString* uploadURL = [[command argumentAtIndex:1] copy];
	if (!uploadURL) {
        [self uploadError:@"UploadURL parameter omitted"];
        return;
    }

    NSString* folderName = [[command argumentAtIndex:2 withDefault:@""] copy];

    NSString* mimeType = [[command argumentAtIndex:3 withDefault:@""] copy];
    if (!mimeType || mimeType.length == 0) {
        mimeType = @"text/plain";
    }

    _uploadProgressCallback = [[command argumentAtIndex:4] copy];
    
    NSRange range = [_localURL rangeOfString:@"localhost:58888/"];
    NSString* filePath = (range.location == NSNotFound) ? _localURL :
                            [_localURL substringFromIndex:(range.location + range.length)];
	
	if (! [[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
		[self uploadError:@"Cannot find the file for upload!"];
		return;
	}
    NSData *FileData = [NSData dataWithContentsOfFile:filePath];
	if (!FileData ) {
        [self uploadError:@"Cannot open the file for upload!"];
		return;
	}
	
    _uploadRequest.sessionInfo = kXDKUploadStep;
	[_uploadRequest uploadFileStream:[NSInputStream inputStreamWithData:FileData]
                   suggestedFilename:[filePath lastPathComponent]
                 suggestedFoldername:folderName
                            MIMEType:mimeType
                          toEndPoint:uploadURL];
}


- (void) cancelUpload:(CDVInvokedUrlCommand*)command
{
	_uploadRequest.sessionInfo = nil;
	_uploading = NO;
    [self fireEvent:@"file.upload.cancel"
            success:YES
         components:@{ @"localURL": quotedString(_localURL) }];
}


#pragma mark - XDKFileUploadRequest delegate methods

- (void)FileUploadRequest:(XDKFileUploadRequest *)inRequest
  didCompleteWithResponse:(NSDictionary *)inResponseDictionary
{
	_uploadRequest.sessionInfo = nil;
	_uploading = NO;
    [self fireEvent:@"file.upload"
            success:YES
         components:@{ @"localURL": quotedString(_localURL) }];
}


- (void)FileUploadRequest:(XDKFileUploadRequest *)inRequest
         didFailWithError:(NSError *)inError
{
	_uploadRequest.sessionInfo = nil;
	_uploading = NO;
    
	NSString* error = [inError description];
	if (error) {
		[self uploadError:error];
    }
}


- (void)FileUploadRequest:(XDKFileUploadRequest *)inRequest
      fileUploadSentBytes:(NSUInteger)inSentBytes
               totalBytes:(NSUInteger)inTotalBytes
{
	if (_uploadProgressCallback) {
		NSString* script = [NSString stringWithFormat:@"%@(%lu, %lu);",
                            _uploadProgressCallback,
                            (unsigned long)inSentBytes,
                            (unsigned long)inTotalBytes];
		XDKLog(@"%@", script);
		[self.commandDelegate evalJs:script];
	}
}

#pragma mark - Utility methods

//! Fire a JavaScript event.
//!
//! Generates a string of JavaScript code to create and dispatch an event.
//! @param eventName    The name of the event (not including the @c "intel.xdk." prefix).
//! @param success      The boolean value to assign to the @a success field in the
//!                     event object.
//! @param components   Each key/value pair in this dictionary will be incorporated.
//!                     (Note that the value must be a string which is the JavaScript
//!                     representation of the value - @c "true" for a boolean value,
//!                     @c "'Hello'" for a string, @c "20" for a number, etc.)
//!
- (void) fireEvent:(NSString*)eventName
           success:(BOOL)success
        components:(NSDictionary*)components
{
    NSMutableString* eventComponents = [NSMutableString string];
    for (NSString *eachKey in components) {
        [eventComponents appendFormat:@"e.%@ = %@;", eachKey, components[eachKey]];
    }
    NSString* script = [NSString stringWithFormat:@"var e = document.createEvent('Events');"
                        "e.initEvent('intel.xdk.%@', true, true);"
                        "e.success = %@;"
                        "%@"
                        "document.dispatchEvent(e);",
                        eventName,
                        (success ? @"true" : @"false"),
                        eventComponents];
    XDKLog(@"%@", script);
    [self.commandDelegate evalJs:script];
}


//! Report an error in a file upload request.
//!
- (void)uploadError:(NSString*)error
{
    [self fireEvent:@"file.upload" success:NO components:@{ @"message": quotedString(error) }];
	_uploading = NO;
}


//! Turn a string into a Javascript string literal.
//!
//! Given an arbitrary string, get a string containing a Javascript string literal that
//! represents the input string. For example:
//!
//! -   <<abc>>         => <<"abc">>
//! -   <<"abc">>       => <<"\"abc\"">>
//! -   <<x=" \t\n\r">> => <<"x=\" \\t\\n\\t\"">>
//!
//! @remarks
//! The implementation relies on the Cocoa built-in JSON serialization code to do the
//! quoting. Since JSON can only represent arrays and objects, the code creates an array
//! containing the input string, gets its JSON representation, and then strips the array
//! literal square brackets from the beginning and end of the string.
//!
//! @param string   The string to be quoted.
//! @return         The string literal that represents @a string.
//!
static NSString* quotedString(NSString* string)
{
    NSError* err;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:@[string] options:0 error:&err];
    NSMutableCharacterSet* trimChars = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
    [trimChars addCharactersInString:@"[]"];
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return [jsonString stringByTrimmingCharactersInSet:trimChars];
}

@end
