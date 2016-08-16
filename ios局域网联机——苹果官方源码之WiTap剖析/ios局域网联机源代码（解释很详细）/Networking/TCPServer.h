/*
     File: TCPServer.h
 Abstract: A TCP server that listens on an arbitrary port.
 Version: 1.8
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2010 Apple Inc. All Rights Reserved.
 
 */

#import <Foundation/Foundation.h>

@class TCPServer;

NSString * const TCPServerErrorDomain;

typedef enum {
    kTCPServerCouldNotBindToIPv4Address = 1,
    kTCPServerCouldNotBindToIPv6Address = 2,
    kTCPServerNoSocketsAvailable = 3,
} TCPServerErrorCode;


@protocol TCPServerDelegate <NSObject>
@optional
//TCPServer用boujour发布服务成功之后我们用来处理一些东西的方法
- (void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name;
//失败的时候我们用来处理一些东西的方法
- (void) server:(TCPServer*)server didNotEnableBonjour:(NSDictionary *)errorDict;
//当TCPServer接受了其他设备的连接请求之后，我们用来处理东西的方法
- (void) didAcceptConnectionForServer:(TCPServer*)server inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr;
@end


@interface TCPServer : NSObject <NSNetServiceDelegate> {
@private
	id _delegate;  //跟踪我们这个TCPServer类的委托
    uint16_t _port; //存储我们发布服务时绑定的Socket的端口号
	uint32_t protocolFamily; //存储我们的socket的协议族
	CFSocketRef witap_socket;//我们的等待其他设备连接的socket
	NSNetService* _netService;//用来发布服务的NSNetService
}
//这个方法里创建并配置我们用来监听网络连接的socket,并创建RunLoop输入源，加入到当前RunLoop中，这样只要有我们的这个socket有连接事件，我们就能得到通知并触发相应的回调
- (BOOL)start:(NSError **)error;
//停止我们的网络连接服务的，让我们取消对网络连接事件的监听，并释放这个监听的socket。
- (BOOL)stop;
//进行NSNetService服务发布的方法
- (BOOL) enableBonjourWithDomain:(NSString*)domain applicationProtocol:(NSString*)protocol name:(NSString*)name; //Pass "nil" for the default local domain - Pass only the application protocol for "protocol" e.g. "myApp"
//停止我们的当前的已经发布的服务
- (void) disableBonjour;
//声明了一个id的属性delegate，这是一个满足TCPServerDelegate协议的属性
@property(assign) id<TCPServerDelegate> delegate;
//它用来返回我们要发布的服务的协议的（这个协议不是委托类的协议，它只是一个代表唯一标识的字符串），并且这个字符串是有要求的，它不能超过14个字符，并且只能包含小写字母、数字和连接符，开关和结尾不能是连接符。
+ (NSString*) bonjourTypeFromIdentifier:(NSString*)identifier;

@end
