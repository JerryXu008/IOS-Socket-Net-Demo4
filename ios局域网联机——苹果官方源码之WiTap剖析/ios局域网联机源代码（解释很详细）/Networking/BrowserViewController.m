/*
     File: BrowserViewController.m
 Abstract: View controller for the service instance list.
 This object manages a NSNetServiceBrowser configured to look for Bonjour services.
 It has an array of NSNetService objects that are displayed in a table view.
 When the service browser reports that it has discovered a service, the corresponding NSNetService is added to the array.
 When a service goes away, the corresponding NSNetService is removed from the array.
 Selecting an item in the table view asynchronously resolves the corresponding net service.
 When that resolution completes, the delegate is called with the corresponding NSNetService.
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

#import "BrowserViewController.h"

#define kProgressIndicatorSize 20.0

// A category on NSNetService that's used to sort NSNetService objects by their name.
//为NSNetService创建一个类别，为这个类别添加一个方法，这个方法是按照NSNetService服务的名字来给它们排序的
@interface NSNetService (BrowserViewControllerAdditions)
- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSNetService *)aService;
@end

@implementation NSNetService (BrowserViewControllerAdditions)
- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSNetService *)aService {
	return [[self name] localizedCaseInsensitiveCompare:[aService name]];
}
@end


@interface BrowserViewController()
//为在BrowserViewController.h文件中没有添加属性的剩余私有变量添加属性声明
@property (nonatomic, retain, readwrite) NSNetService *ownEntry;
@property (nonatomic, assign, readwrite) BOOL showDisclosureIndicators;
@property (nonatomic, retain, readwrite) NSMutableArray *services;
@property (nonatomic, retain, readwrite) NSNetServiceBrowser *netServiceBrowser;
@property (nonatomic, retain, readwrite) NSNetService *currentResolve;
@property (nonatomic, retain, readwrite) NSTimer *timer;
@property (nonatomic, assign, readwrite) BOOL needsActivityIndicator;
@property (nonatomic, assign, readwrite) BOOL initialWaitOver;
//用来停止当前正在解析的NSNetService服务的发布或者解析动作的
- (void)stopCurrentResolve;
//用来延迟处理一些操作的方法
- (void)initialWaitOver:(NSTimer *)timer;
@end

@implementation BrowserViewController

@synthesize delegate = _delegate;
@synthesize ownEntry = _ownEntry;
@synthesize showDisclosureIndicators = _showDisclosureIndicators;
@synthesize currentResolve = _currentResolve;
@synthesize netServiceBrowser = _netServiceBrowser;
@synthesize services = _services;
@synthesize needsActivityIndicator = _needsActivityIndicator;
@dynamic timer; //@dynamic是说这个set和get方法必须由程序员自己实现
@synthesize initialWaitOver = _initialWaitOver;

////初始化这个BroswerViewController类 参数一：title 参数二 ：是否显示cell的accessoryView  参数三：是否显示取消按钮
- (id)initWithTitle:(NSString *)title showDisclosureIndicators:(BOOL)show showCancelButton:(BOOL)showCancelButton {
	
	if ((self = [super initWithStyle:UITableViewStylePlain])) {
		self.title = title;
		_services = [[NSMutableArray alloc] init]; //初始化承载搜索到的服务的数组
		self.showDisclosureIndicators = show; //保存是否显示cell的accessoryView
        //是否添加取消按钮
		if (showCancelButton) {
			// add Cancel button as the nav bar's custom right view
			UIBarButtonItem *addButton = [[UIBarButtonItem alloc]
										  initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelAction)];
			self.navigationItem.rightBarButtonItem = addButton;
			[addButton release];
		}
        
		// Make sure we have a chance to discover devices before showing the user that nothing was found (yet)
        //在一秒钟后调用initialWaitOver方法,主要是用来保证在显示给用户之前，有充足的时间让它搜索到服务的。
        //initWithTitle是在picker中的init方法中初始化的，在这个initWithTitle的方法之后，会调用[self.bvc searchForServicesOfType:type inDomain:@"local"];
        //这个方法是负责搜索服务，所以在下面的代码中会延迟执行，这样就可以显示搜索出来的服务了
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(initialWaitOver:) userInfo:nil repeats:NO];
	}
    
	return self;
}
//属性searchingForServicesString的get方法
- (NSString *)searchingForServicesString {
	return _searchingForServicesString;
}
//属性searchingForServicesString的set方法，在set方法里，多了一点东西，也是当搜索到的服务数为0的时候，重新刷新表视图，目地是让这个搜索的服务的类型名字出现（后面在表视图的数据源方法里会看到）。
// Holds the string that's displayed in the table view during service discovery.
- (void)setSearchingForServicesString:(NSString *)searchingForServicesString {
	if (_searchingForServicesString != searchingForServicesString) {
		[_searchingForServicesString release];
		_searchingForServicesString = [searchingForServicesString copy];
        
        // If there are no services, reload the table to ensure that searchingForServicesString appears.
		if ([self.services count] == 0) {
			[self.tableView reloadData];
		}
	}
}
//ownName属性的get方法
- (NSString *)ownName {
	return _ownName;
}
//ownName属性的set方法
// Holds the string that's displayed in the table view during service discovery.
//如果这个ownEntry这个属性就是自己发布的服务是有效的话，就把这个服务加入到services这个服务数组里，
//然后对这个数组里的所有服务的名字进行比较，如果有服务的名字和我们想要让ownName这个属性设置成的名字一样的话，就把这个服务设为ownEntry，同时从services服务数组里把这个服务移除。这样做的用意是，当我们的ownEntry属性当前是有效的前提下，想换一个服务为作为自己的服务的话，这样就可以完成两个服务的交换。然后再次重新刷新表视图。

/**难点理解之一*/
- (void)setOwnName:(NSString *)name {
	if (_ownName != name) {
		_ownName = [name copy];
		
		if (self.ownEntry)
			[self.services addObject:self.ownEntry];
		
		NSNetService* service;
		
		for (service in self.services) {
			if ([service.name isEqual:name]) {
				self.ownEntry = service;
				[_services removeObject:service];
				break;
			}
		}
		
		[self.tableView reloadData];
	}
}

// Creates an NSNetServiceBrowser that searches for services of a particular type in a particular domain.
// If a service is currently being resolved, stop resolving it and stop the service browser from
// discovering other services.
//真正开始搜索相应的服务的方法
//参数一：[TCPServer bonjourTypeFromIdentifier:kGameIdentifier]  参数二：@"local"
- (BOOL)searchForServicesOfType:(NSString *)type inDomain:(NSString *)domain {
	/**之前的清理动作***/
	[self stopCurrentResolve]; //假设有服务正在服务的话就先停止这个解析
	[self.netServiceBrowser stop];//停止搜索服务的动作
	[self.services removeAllObjects]; //把之前搜索到的所有服务从服务数组中移除
    /**之前的清理动作结束***/
    
    //初始化一个NSNetServiceBrowser对象，如果初始化失败，返回搜索失败
	NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
	if(!aNetServiceBrowser) {
        // The NSNetServiceBrowser couldn't be allocated and initialized.
		return NO;
	}
    //把这个NSNetServiceBrowser对象的委托设为这个类本身（因为这个类已经声明自己符合它的协议了），然后把这个对象赋给netServiceBrowser属性。
    aNetServiceBrowser.delegate = self;
	self.netServiceBrowser = aNetServiceBrowser;
	[aNetServiceBrowser release];
    // 用这个searchForServicesOfType:inDomain：来搜索服务，第一个参数是要搜索的服务的类型名，第二个参数是要搜索的域的名字。
    [self.netServiceBrowser searchForServicesOfType:type inDomain:domain];  //开始搜寻存在的服务。
    // 重新刷新表视图，返回搜索成功
	[self.tableView reloadData];
	return YES;
}
//timer的set和get方法
- (NSTimer *)timer {
	return _timer;
}
//在这个timer的set方法里，在把timer设为新的newTimer前，先停止并释放原先的timer
// When this is called, invalidate the existing timer before releasing it.
- (void)setTimer:(NSTimer *)newTimer {
	[_timer invalidate];
	[newTimer retain];
	[_timer release];
	_timer = newTimer;
}
//分区是1
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	// If there are no services and searchingForServicesString is set, show one row to tell the user.
	NSUInteger count = [self.services count];
    //先获取存储服务的数组的元素个数，如果这个元素个数是0，并且我们搜索的服务类型的名字有效，
    //并且initialWaitOver属性为真（这个代表着我们已经等待了一秒钟了，initialWaitOver方法执行完了）的话，我们就返回1，否则则直接返回服务数组的元素的个数
    if (count == 0 && self.searchingForServicesString && self.initialWaitOver)
		return 1;
    
	return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	static NSString *tableCellIdentifier = @"UITableViewCell";
	UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:tableCellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableCellIdentifier] autorelease];
	}
	
	NSUInteger count = [self.services count];
	if (count == 0 && self.searchingForServicesString) {
        // If there are no services and searchingForServicesString is set, show one row explaining that to the user.
        // 如果服务数为0，并且searchingForServicesString属性有效，就显示一行，这一行的文本信息是这个searchingForServicesStirng属性，就是要搜索的服务类型的名字。
        cell.textLabel.text = self.searchingForServicesString;
		cell.textLabel.textColor = [UIColor colorWithWhite:0.5 alpha:0.5];
		cell.accessoryType = UITableViewCellAccessoryNone;
		// Make sure to get rid of the activity indicator that may be showing if we were resolving cell zero but
		// then got didRemoveService callbacks for all services (e.g. the network connection went down).
		//然后，如果cell的accessoryView有效，把accessoryView置为nil（为了防止当我们的连接断开的时候，之前显示的服务已经移除的情况下这里还在显示信息）。
        if (cell.accessoryView)
			cell.accessoryView = nil;
		return cell;
	}
	
	// Set up the text for the cell
	NSNetService *service = [self.services objectAtIndex:indexPath.row];
	cell.textLabel.text = [service name];
	cell.textLabel.textColor = [UIColor blackColor];
	cell.accessoryType = self.showDisclosureIndicators ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
	
	// Note that the underlying array could have changed, and we want to show the activity indicator on the correct cell
    //如果needsActivityIndicator属性为真，就是说我们需要显示活动指示器（就是我们常看到的齿轮状的转动的进度指示器），并且当前正在解析的服务就是当前这个行的服务的话
    //，初始化并设置一个活动指示器，把它设为当前cell的accessoryView。否则的话，就判断这个当前cell的accessoryView是否有效，有效的话就把它置为nil。
    //这段代码在不点击行的时候不会发生，当点击行的时候，说明需要解析这一行的服务，在点击事件里会重新加载这一行，所以又会执行- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
    //也就是本方法，用下面的代码来显示一个加载等待的图像
    if (self.needsActivityIndicator && self.currentResolve == service) {
		if (!cell.accessoryView) {
			CGRect frame = CGRectMake(0.0, 0.0, kProgressIndicatorSize, kProgressIndicatorSize);
			UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
			[spinner startAnimating];
			spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
			[spinner sizeToFit];  //调用这个方法时,你想调整当前视图,以便它使用最合适的空间量,如果你想要一个适应父视图的这个视图,您应该将它添加到父视图之前调用该方法。
            spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
										UIViewAutoresizingFlexibleRightMargin |
										UIViewAutoresizingFlexibleTopMargin |
										UIViewAutoresizingFlexibleBottomMargin);
			cell.accessoryView = spinner;
			[spinner release];
		}
	} else if (cell.accessoryView) {
		cell.accessoryView = nil;
	}
	
	return cell;
}
//这个方法的作用是当我们点击tableView的一行并松开手指的时候，告诉它的委托一个特定行将要被选中，如果服务数组的元素个数为0的话返回nil，表明不希望这个被点的行被选中（在这个例子里就是要忽略没有搜索到服务只有一个cell显示的是要搜索的服务的名字的情况），正常返回indexPath表示，希望被点的这行被选中。
//但是据我调试过程中，始终没有用到 searchingForServicesString这个属性
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// Ignore the selection if there are no services as the searchingForServicesString cell
	// may be visible and tapping it would do nothing
	if ([self.services count] == 0)
		return nil;
    
	return indexPath;
}
//********************************************停止当前的解析
- (void)stopCurrentResolve {
    //给当前活动指示器赋值为假
	self.needsActivityIndicator = NO;
    //调用timer属性的set方法，把这个timer置为nil，在这个timer的set方法里，把这个timer设为新的值之前先释放了之前的timer
    self.timer = nil;
    //停止当前正在尝试解析或发布的服务
	[self.currentResolve stop];  //通过调试我得知，如果是接收者的话，因为没有点击行，所以self.currentResolve是null，不会调用这个方法，注意self.currentResolve是NSNetService,而不是TCPServer，后者也有一个stop方法
    //把currentResolve属性置为nil。
	self.currentResolve = nil;
}
//点击行之后执行的方法
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// If another resolve was running, stop it & remove the activity indicator from that cell
    //有另一个服务解析正在运行，停止它，并从它对应的cell里移除活动指示器。
    if (self.currentResolve) {
		// Get the indexPath for the active resolve cell
		NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.services indexOfObject:self.currentResolve] inSection:0];
		
		// Stop the current resolve, which will also set self.needsActivityIndicator
        //停止当前的解析，并把needsActivityIndicator设置为false
		[self stopCurrentResolve];
		//如果找到了这一行，重新加载cell来移除indicator
		// If we found the indexPath for the row, reload that cell to remove the activity indicator
		if (indexPath.row != NSNotFound)
			[self.tableView reloadRowsAtIndexPaths:[NSArray	arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
	}
 	
	// Then set the current resolve to the service corresponding to the tapped cell
    //设置这个当前在解析的服务为我们选中的行对应的服务
	self.currentResolve = [self.services objectAtIndex:indexPath.row];
    //设置委托
	[self.currentResolve setDelegate:self];
    
	// Attempt to resolve the service. A value of 0.0 sets an unlimited time to resolve it. The user can
	// choose to cancel the resolve by selecting another service in the table view.
    //开始解析这个选中的服务，Timeout为0是说，对于这个解析过程来说没有超时时间限制
	[self.currentResolve resolveWithTimeout:0.0];
	
	// Make sure we give the user some feedback that the resolve is happening.
	// We will be called back asynchronously, so we don't want the user to think we're just stuck.
	// We delay showing this activity indicator in case the service is resolved quickly.
    //初始化一个NSTimer，用于在1秒钟后调用showWaiting方法，同时这个NSTimer的userInfo被设置为这个当前解析的服务。然后把这个NSTimer赋给timer属性。（还记得timer属性的set方法吗？在把timer赋为新的值之前是先取消并释放之前的timer。）
    //它主要就是在解析选中的服务开始1秒钟后，显示活动指示器的。（事实上解析的过程一般情况下是很快的，会在1秒钟内完成，
    //在解析完成之后会有一个回调方法被调用，在这个回调方法里其实是取消了这个timer的，也就是说如果1秒钟内完成了解析，这个showWaiting方法是不会调用的）
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(showWaiting:) userInfo:self.currentResolve repeats:NO];
}

// If necessary, sets up state to show an activity indicator to let the user know that a resolve is occuring.
//从这个timer里得到在tableView:didSelectRowAtIndexPath方法里选中的服务
//，然后把needsActivityIndicator属性设为真，就是说现在需要显示活动指示器了，
//然后根据这个服务在服务数据里的索引号得到这个服务在tableView里的行索引，
//再根据这个得到的行索引对这个行进行刷新以显示这个活动指示器，并且也取消掉这个行的选中状态（就是取消这个行的高亮）。
- (void)showWaiting:(NSTimer *)timer {
	if (timer == self.timer) {
		NSNetService* service = (NSNetService*)[self.timer userInfo];
		if (self.currentResolve == service) {
			self.needsActivityIndicator = YES;
            
			NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.services indexOfObject:self.currentResolve] inSection:0];
			if (indexPath.row != NSNotFound) {
                //重新加载
				[self.tableView reloadRowsAtIndexPaths:[NSArray	arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
				// Deselect the row since the activity indicator shows the user something is happening.
				[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
			}
		}
	}
}
//设置这个initialWaitOver属性为真，如果搜索到的服务数为0的话，重新刷新这个表视图。之所以要在1秒钟后调用这个方法，是要给我们留出足够的时间来搜索发现服务。
- (void)initialWaitOver:(NSTimer *)timer {
	self.initialWaitOver= YES;
	if (![self.services count])
		[self.tableView reloadData];
}
// 这是一个排序方法，用我们在NSNetService的分类的里定义的排序方法对这个服务数组里的服务进行排序，然后再根据这个顺序刷新显示tableView。
- (void)sortAndUpdateUI {
	// Sort the services by name.
	[self.services sortUsingSelector:@selector(localizedCaseInsensitiveCompareByName:)];
	[self.tableView reloadData];
}
// 这个方法会在NSNetServiceBrowser探索到的服务中，有服务变为不可用了或者消失了的时候被调用
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing {
	// If a service went away, stop resolving it if it's currently being resolved,
	// remove it from the list and update the table view if no more events are queued.
	//如果当前正在解析的服务就是这个消失的服务，停止对它的解析
	if (self.currentResolve && [service isEqual:self.currentResolve]) {
		[self stopCurrentResolve];
	}
    //把这个不可用的服务从服务数组里移除，如果这个不可用的的服务是我们自己的服务，把这个我们自己的服务设置为nil
	[self.services removeObject:service];
	if (self.ownEntry == service)
		self.ownEntry = nil;
	
	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
    //如果没有更多的服务不可用消息到达的时候，更新服务列表及tableView
	if (!moreComing) {
		[self sortAndUpdateUI];
	}
}
//这个会在搜索到可用服务时调用
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
	// If a service came online, add it to the list and update the table view if no more events are queued.
    //如果新发现在的这个服务和我们自己程序发布的服务的名字一样的话，我们就把这个用来跟踪自己发布的服务的这个ownEntry属性设为这个服务。如果名字不一样的话，就把它加入到服务数组里
	if ([service.name isEqual:self.ownName])
		self.ownEntry = service;
	else
		[self.services addObject:service];
    
	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
    //如果没有更多的可用服务被发现的话，就更新服务列表和tableView
	if (!moreComing) {
		[self sortAndUpdateUI];
	}
}

// This should never be called, since we resolve with a timeout of 0.0, which means indefinite
//在NSNetService解析失败时调用的，在这个例子里这个方法是永远不会被调用的，因为前面设置解析时间限制时我们用的是0，它是说是没有限制的，永远不会超时的。这个方法里，停止当前在解析的服务，重新刷新tableView。
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
	[self stopCurrentResolve];
	[self.tableView reloadData];
}
//*********************************************************这个方法是在NSNetService解析成功时调用的（只针对请求者）。也就是 [self.currentResolve resolveWithTimeout:0.0];
//这个方法成功之后调用的   首先是用断言来保证触发这个回调方法的服务是我们正在解析的服务currentResolve。
//先对这个服务进行一次retain操作，然后停止对这个服务的解析操作，对它的委托调用browserViewController：
//didResolveInstance:方法（事实上它的委托是AppController类，这个方法后面再讲），先前执行了一次retain，现在对这个服务执行release操作。
- (void)netServiceDidResolveAddress:(NSNetService *)service {
	assert(service == self.currentResolve);
	
	[service retain];
	[self stopCurrentResolve];
	
	[self.delegate browserViewController:self didResolveInstance:service];
	[service release];
}
//点击取消之后执行的方法，很简单地让它的委托去处理了，这个委托方法后面遇到时再说
- (void)cancelAction {
	[self.delegate browserViewController:self didResolveInstance:nil];
}

- (void)dealloc {
	// Cleanup any running resolve and free memory
	[self stopCurrentResolve];
	self.services = nil;
	[self.netServiceBrowser stop];
	self.netServiceBrowser = nil;
	[_searchingForServicesString release];
	[_ownName release];
	[_ownEntry release];
	
	[super dealloc];
}

@end
