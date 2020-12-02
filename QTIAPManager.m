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
#import "QTIAPManager.h"

@interface QTIAPManager() <SKProductsRequestDelegate, SKPaymentTransactionObserver,QTIAPManagerDelegate> {
    SKProduct *myProduct;
}

@property (nonatomic, strong) SKPaymentTransaction * currentTransaction;

@end

@implementation QTIAPManager

#pragma mark - ================ Singleton ================= 

+ (instancetype)sharedManager {
    
    static QTIAPManager *iapManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        iapManager = [QTIAPManager new];
 
    });
    
    return iapManager;
}

#pragma mark - ================ Public Methods =================

#pragma mark ==== 请求商品 1
- (BOOL)requestProductWithId:(NSString *)productId{
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];

    if (productId.length > 0) {
        NSLog(@"请求商品: %@", productId);
        SKProductsRequest *productRequest = [[SKProductsRequest alloc]initWithProductIdentifiers:[NSSet setWithObject:productId]];
        productRequest.delegate = self;
        [productRequest start];
        return YES;
    } else {
        NSLog(@"商品ID为空");
    }
    return NO;
}

#pragma mark ==== 购买商品 3
- (BOOL)purchaseProduct:(SKProduct *)skProduct {
    
    if (skProduct != nil) {
        if ([SKPaymentQueue canMakePayments]) {
            SKPayment *payment = [SKPayment paymentWithProduct:skProduct];
            [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
            NSLog(@"3333333：%@",payment);

            return YES;
        } else {
            NSLog(@"失败，用户禁止应用内付费购买.");
        }
    }
    return NO;
}

#pragma mark ==== 商品恢复
- (BOOL)restorePurchase {
    
    if ([SKPaymentQueue canMakePayments]) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        [[SKPaymentQueue defaultQueue]restoreCompletedTransactions];
        return YES;
    } else {
        NSLog(@"失败,用户禁止应用内付费购买.");
    }
    return NO;
}

#pragma mark ==== 结束这笔交易
- (void)finishTransaction {
	[[SKPaymentQueue defaultQueue] finishTransaction:self.currentTransaction];
}

#pragma mark ====  刷新凭证
- (void)refreshReceipt {
    SKReceiptRefreshRequest *request = [[SKReceiptRefreshRequest alloc] init];
    request.delegate = self;
    [request start];
}

#pragma mark - ================ SKRequestDelegate =================5

- (void)requestDidFinish:(SKRequest *)request {
    if ([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
        NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
        [_delegate successedWithReceipt:receiptData];
    }
}

#pragma mark - ================ SKProductsRequest Delegate =================
//2
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
    NSArray *myProductArray = response.products;
    if (myProductArray.count > 0) {
        myProduct = [myProductArray objectAtIndex:0];
        NSLog(@"商品为：%@",myProduct);
        [_delegate receiveProduct:myProduct];
    } else {
        NSLog(@"无法获取产品信息，购买失败。");
        [_delegate receiveProduct:myProduct];
    }
}

#pragma mark - ================ SKPaymentTransactionObserver Delegate =================
//4
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing: //商品添加进列表
                NSLog(@"商品:%@被添加进购买列表",myProduct.productIdentifier);
                break;
            case SKPaymentTransactionStatePurchased://交易成功
                
                [self completeTransaction:transaction];
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];//记得关闭交易事件
                break;
            case SKPaymentTransactionStateFailed://交易失败
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored://已购买过该商品
                // 消耗型不支持恢复购买
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateDeferred://交易延迟
                break;
            default:
                break;
        }
    }
}

#pragma mark - ================ Private Methods =================

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    
    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
    [_delegate successedWithReceipt:receiptData];
    self.currentTransaction = transaction;
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    
    if (transaction.error.code != SKErrorPaymentCancelled && transaction.error.code != SKErrorUnknown) {
        [_delegate failedPurchaseWithError:transaction.error.localizedDescription];
    }
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    self.currentTransaction = transaction;
}

@end
