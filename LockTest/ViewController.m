//
//  ViewController.m
//  LockTest
//
//  Created by 王鹭飞 on 2018/12/29.
//  Copyright © 2018 王鹭飞. All rights reserved.
//

#import "ViewController.h"
#import <pthread.h>
#import <os/lock.h>
static NSInteger CONDITION_NO_DATA = 0;        //条件一： 没有数据
static NSInteger CONDITION_HAS_DATA = 1;       //条件二： 有数据
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self func];
    // Do any additional setup after loading the view, typically from a nib.
}
//各个锁的用啊
-(void)threadA{
    
    NSLog(@"name A: %@",[NSThread currentThread]);
}
-(void)threadB{
    NSLog(@"name B: %@",[NSThread currentThread]);
}
-(void)func{
    {
        NSLock *lock = [[NSLock alloc]init];
        lock.name = @"NSLock";
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            [lock lock];
            
            [self performSelector:@selector(threadA) withObject:nil];
            [lock unlock];
        });
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            [lock lock];
            
            [self performSelector:@selector(threadB) withObject:nil];
            [lock unlock];
        });
    }
    {
        NSConditionLock *lock = [[NSConditionLock alloc]initWithCondition:CONDITION_NO_DATA];
        lock.name = @"NSConditionLock";
        //默认一个条件
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            //1. 当满足 【没有数据的条件时】进行加锁
            [lock lockWhenCondition:CONDITION_NO_DATA];
            NSLog(@"有数据了");
            //2. 生产者生成数据
            //.....
            
            //3. 解锁，并设置新的条件，已经有数据了
            [lock unlockWithCondition:CONDITION_HAS_DATA];
        });
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            //消费者，加锁与解锁的过程
            
            //1. 当满足 【有数据的条件时】进行加锁
            [lock lockWhenCondition:CONDITION_HAS_DATA];
            
            //2. 消费者消费数据
            //.....
            NSLog(@"消费数据了");
            //3. 解锁，并设置新的条件，没有数据了
            [lock unlockWithCondition:CONDITION_NO_DATA];
        });
        
        }
    {
        NSCondition *condition = [[NSCondition alloc]init];
        condition.name = @"NSCondition";
        NSMutableArray *products = [[NSMutableArray  alloc]initWithCapacity:30];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [condition lock];
            while(products.count == 0){
                NSLog(@"等待产品");
                [condition wait];
            }
            [products removeObjectAtIndex:0];
            NSLog(@"消费产品");
            [condition unlock];
        });
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [condition lock];
            [products addObject:@"一个"];
            [condition signal];
            NSLog(@"生产了一个产品");
            [condition unlock];
        });
    }
    {
        NSRecursiveLock *recursiveLock = [[NSRecursiveLock alloc]init];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            static void (^RecursiveMethod)(int);
            
            RecursiveMethod = ^(int value) {
                
                [recursiveLock lock];
                if (value > 0) {
                    
                    NSLog(@"value = %d", value);
                    sleep(2);
                    RecursiveMethod(value - 1);
                }
                [recursiveLock unlock];
            };
            
            RecursiveMethod(5);
        });
    }
    {
        
        dispatch_queue_t queque = dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT);
        //异步执行
        dispatch_async(queque, ^{
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [self getToken:semaphore];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            [self request];
        });
        
        NSLog(@"main thread");
    }
    {
        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);  // 定义锁的属性
        
        pthread_mutex_t mutex;
        pthread_mutex_init(&mutex, &attr); // 创建锁
        
        pthread_mutex_lock(&mutex); // 申请锁
        NSLog(@"pthread_mutexattr_t互斥锁");
        pthread_mutex_unlock(&mutex); // 释放锁
    }
    {
        os_unfair_lock_t unfairLock;
        unfairLock = &(OS_UNFAIR_LOCK_INIT);
        os_unfair_lock_lock(unfairLock);
        NSLog(@"os_unfair_lock_t");
        os_unfair_lock_unlock(unfairLock);
    }
}
-(void)getToken:(dispatch_semaphore_t)semaphore{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionTask *task = [session dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.baidu.com"]] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"get Token");
        //成功拿到token，发送信号量:
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
}
-(void)request{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"刷新数据");
    });
}
@end
