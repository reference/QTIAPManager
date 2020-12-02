/**
 MIT License
 
 Copyright (c) 2018 Scott Ban (https://github.com/reference/BDToolKit)
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */
#import "IAPController.h"
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

@interface IAPController ()<SKPaymentTransactionObserver,SKProductsRequestDelegate>

@property (nonatomic, copy)  NSString *purchID;
@property (nonatomic, copy)  NSString *serverid;
@property (nonatomic, copy)  NSString *extra;     //透传参数
@property (nonatomic, strong) IAPCompletionHandle handle;
@property (nonatomic, strong) QTNetwork *netRequest;
@property (nonatomic, assign) BOOL isRun;
@end

@implementation IAPController

#pragma mark - system lifecycle
-(instancetype)init{
    self = [super init];
    if (self) {
        // 购买监听写在程序入口,程序挂起时移除监听,这样如果有未完成的订单将会自动执行并回调 paymentQueue: updatedTransactions: 方法
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

#pragma mark - dealloc
-(void)dealloc{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

#pragma mark - Public Method
//1
- (void)startPurchWithID:(NSString *)purchID serverId:(NSString *)sid extraStr:(NSString *)extra completeHandle:(IAPCompletionHandle)handle{
    if (self.isRun == NO) {
        self.isRun = YES;
        if (purchID) {
            if ([SKPaymentQueue canMakePayments]) {
                [SVProgressHUD show];
                [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
                NSLog(@"----------苹果内购开始购买🍎------------");
                NSLog(@"内购参数:purchID:%@, serverID:%@, extra:%@",purchID,sid,extra);
                // 开始购买服务
                _netRequest = [[QTNetwork alloc] init];
                _purchID = purchID;
                _serverid = sid;
                _extra = extra;
                _handle = handle;
                NSSet *nsset = [NSSet setWithArray:@[purchID]];
                SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
                request.delegate = self;
                [request start];
            }else{
                [self handleActionWithType:kIAPPurchNotArrow data:nil];
            }
        }
    }
}

#pragma mark - Private Method
- (void)handleActionWithType:(IAPPurchType) type data:(NSData *)data{
#if DEBUG
    switch (type) {
        case kIAPPurchSuccess:
            [SVProgressHUD showSuccessWithStatus:@"购买成功"];
            break;
        case kIAPPurchFailed:
            [SVProgressHUD showInfoWithStatus:@"购买失败"];
            break;
        case kIAPPurchCancle:
            [SVProgressHUD showInfoWithStatus:@"用户取消购买"];
            break;
        case kIAPPurchVerFailed:
            [SVProgressHUD showInfoWithStatus:@"订单校验失败"];
            break;
        case kIAPPurchVerSuccess:
            [SVProgressHUD showInfoWithStatus:@"订单校验成功"];
            break;
        case kIAPPurchNotArrow:
            [SVProgressHUD showInfoWithStatus:@"不允许程序内付费"];
            break;
            
        default:
            break;
    }
#endif
    if (self.handle) {
        self.handle(type, data);
    }
}

#pragma mark - SKProductsRequestDelegate
//2从苹果接收的product信息
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    
    NSArray *product = response.products;
    NSLog(@"商品id:%@",response.products);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0), dispatch_get_main_queue(), ^{
        self.isRun = NO;
    });

    if ([product count] <= 0) {
        
        NSLog(@"----------没有商品----------");
        [SVProgressHUD showErrorWithStatus:@"没有商品"];
        // 购买失败通知
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kQTPlatformPaymentFailedNotification" object:nil];
        
       
      
        return;
        
    }
    
    SKProduct *p = nil;
    for (SKProduct *pro in product) {
        if ([pro.productIdentifier isEqualToString:self.purchID]) {
            p = pro;
            break;
        }
    }
    
    NSLog(@"productID:%@",response.invalidProductIdentifiers);
    NSLog(@"产品付费数量: %lu",(unsigned long)[product count]);
    NSLog(@"%@",[p description]);
    NSLog(@"%@",[p localizedTitle]);
    NSLog(@"%@",[p localizedDescription]);
    NSLog(@"%@",[p price]);
    NSLog(@"%@",[p productIdentifier]);
    NSLog(@"---发送购买请求---");

    SKPayment *payment = [SKPayment paymentWithProduct:p];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

#pragma mark - SKPaymentTransactionObserver
// 3监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    for (SKPaymentTransaction *tran in transactions) {
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:
            {
                NSLog(@"交易完成");
                [SVProgressHUD showSuccessWithStatus:@"交易完成"];
                
                NSString *product = tran.payment.productIdentifier;
                NSData* data = tran.transactionReceipt;
                
                // NSData *receipt = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
                //
                NSString *nsDataStr =[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                
                // 调用上交服务器方法
                [self completePay:product NSData:nsDataStr];
                // 购买结束
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
            }
            case SKPaymentTransactionStatePurchasing:
                
                NSLog(@"商品添加进列表");
                
                break;
            case SKPaymentTransactionStateRestored:
                NSLog(@"已经购买过商品");
                [SVProgressHUD showErrorWithStatus:@"已经购买过商品..."];
                // 消耗型不支持恢复购买
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            case SKPaymentTransactionStateFailed:
                NSLog(@"交易失败");
                [SVProgressHUD showErrorWithStatus:@"交易失败..."];
                // 购买失败的通知
                [[NSNotificationCenter defaultCenter] postNotificationName:@"kQTPlatformPaymentFailedNotification" object:nil];
                [self failedTransaction:tran];
                break;
            default:
                break;
        }
    }
}

#pragma mark -- 交易成功后，把内付信息提交服务器
//4
- (void)completePay:(NSString *)productId NSData:(NSString *)data {
    NSUserDefaults *user = [NSUserDefaults standardUserDefaults];
    
    NSDictionary *parameters = @{
                                @"act" : @"valid",
                                 @"serverid" : _serverid,
                                 @"appid" : [user objectForKey:@"gameId"],//[GlobalTool getGameID]
                                 @"productid" : productId,
                                 @"nsdata" : data,
                                 @"mid" : [user objectForKey:@"userId"],//[GlobalTool getUserID]
                                @"serverName" : [user objectForKey:@"serverName"],


                                 @"debug" : @"1",
                                 @"extra" : _extra,
                                 @"idfa" : [user objectForKey:@"deviceIDFA"],//[GlobalTool getDeviceIDFA]
                                 @"idfv" : [user objectForKey:@"deviceIDFV"]//[GlobalTool getDeviceIDFV]
                                 };
    
    NSLog(@"------内购提交服务器参数parameters：%@",parameters);
    NSLog(@"serverid是：%@，prodvctid是：%@",_serverid,productId);
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    //更改默认请求的发送请求的二进制数据为JSON格式的二进制更改默认的序列化方式
    //    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    //更改响应默认的解析方式为字符串解析
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    //    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    //接收类型不一致请替换一致text/html或别的
    manager.responseSerializer.acceptableContentTypes= [NSSet setWithObjects:@"application/json",@"text/json",@"text/javascript",@"text/html",nil];
    if ([GlobalTool isBlankDictionary:parameters]) {
        [SVProgressHUD showErrorWithStatus:@"网络错误，请检查网络"];
        NSLog(@"空字典为:%@",parameters);
    }else{
    [manager POST:URL_APPSTORE_CHECK parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"---------内购请求返回值：responseObject:%@",responseObject);
        if (responseObject != nil) {
            NSData *strData = responseObject;
            NSString *nameStr =  [[NSString alloc]initWithData:strData encoding:NSUTF8StringEncoding];
            if ([nameStr isEqualToString:@"0"]) {
                [SVProgressHUD showErrorWithStatus:@"服务器校验失败,请重试"];
            }else {
                // 购买成功的通知
                [[NSNotificationCenter defaultCenter] postNotificationName:@"kQTPlatformPaymentSuccessNotification" object:nil];
                NSLog(@"校验成功");
//                [SVProgressHUD showSuccessWithStatus:@"校验成功"];
            }
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [SVProgressHUD showErrorWithStatus:@"验证失败"];
    }];
    }
    /*
    [_netRequest sendPostRequestURL:URL_APPSTORE_CHECK parameters:parameters completionBlockWithSuccess:^(NSDictionary *resultDict) {
        NSData *strData = responseObject;
     
        NSString *nameStr =  [[NSString alloc]initWithData:strData encoding:NSUTF8StringEncoding];
     
        if ([status isEqualToString:@"0"]) {
            [SVProgressHUD showErrorWithStatus:@"服务器校验失败,请重试"];
        }else {
            [SVProgressHUD showSuccessWithStatus:@"校验成功"];
        }
    } andFailure:^(NSError *error, NSString *errorMsg) {
        NSLog(@"验证失败!");
        NSLog(@"error:%@",error);
        [SVProgressHUD showErrorWithStatus:@"验证失败"];
    }];
     */
}

// 交易失败
- (void)failedTransaction:(SKPaymentTransaction *) transaction{
    NSLog(@"购买失败的原因：%@",transaction.error);
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [self handleActionWithType:kIAPPurchFailed data:nil];
        [SVProgressHUD showErrorWithStatus:@"购买失败"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kQTPlatformPaymentFailedNotification" object:nil];
    }else{
        [self handleActionWithType:kIAPPurchCancle data:nil];
        [SVProgressHUD showInfoWithStatus:@"取消购买"];
        // 取消购买通知
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kQTPlatformPaymentGiveupNotification" object:nil];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

// 请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    [SVProgressHUD dismiss];
    [SVProgressHUD showErrorWithStatus:@"网络错误,请检查网络..."];
    // 购买失败的通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kQTPlatformPaymentFailedNotification" object:nil];
    NSLog(@"----------错误---------:%@",error);

}

// 请求结束
-(void)requestDidFinish:(SKRequest *)request{
    [SVProgressHUD dismiss];

    NSLog(@"----------反馈信息结束----------");

}


@end
