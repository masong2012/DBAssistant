//
//  ViewController.m
//  Demo
//
//  Created by MaSong on 2017/8/9.
//  Copyright © 2017年 MaSong. All rights reserved.
//

#import "ViewController.h"
#import "User.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    User *user = [[User alloc]init];
    user.name = @"mason";
    user.height = 180.23;
    user.num = 123456;
    [user saveModel];
    
    NSLog(@"users count: %ld",User.allModels.count);
    
    user = [User firstModelWhere:@{DBRowId: @(1)}];
    NSLog(@"name %@,num: %ld,height: %lf",user.name,user.num,user.height);
    
    
    [user updateModel:@{@"name": @"Dear"}];
    
    user = [User firstModelWhere:@{DBRowId: @(1)}];
    NSLog(@"name %@,num: %ld,height: %lf",user.name,user.num,user.height);
    
    
    [user deleteModel];
    NSLog(@"users count: %ld",User.allModels.count);
    
    
    
}




@end
