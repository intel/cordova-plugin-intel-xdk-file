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

var http = require('http');
var fs = require('fs');
var path = require('path');

http.createServer(requestListener).listen(8000);

function requestListener(request, response){

	var folderName = request.headers['folderName'] || 'PicturesLibrary';	

	fs.mkdir(path.join(folderName), function(e){
		if(!e){
			console.log(folderName + "is created now.");
		}
	});


	fs.open(path.join(folderName , 'upload_file.jpg'), 'w+', null, function(err, fd){
		if(err){
			console.log('Open error!');
		}

		if(fd){
			request.on('data', function(chunk){
				fs.write(fd, chunk, 0, chunk.length, null, function(err){
					if(err){
						console.log('Write error');
					}
				});
			});
		}
	});


	

	// request.on('end', function(){
	// 	console.log('============================');
	// 	console.log('data.length: ' + length);
	// });	
}