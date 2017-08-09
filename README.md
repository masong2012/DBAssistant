# DBAssistant	

```
DBAssistant base on FMDB and it provide a simple way to access sqlite database.
```

#### Getting started

* add  pod ‘DBAssistant’  to your Podfile
* run pod install
* import "NSObject+DB.h"

#### Example

create a file user.h

```
@interface User : NSObject
@property (strong, nonatomic) NSString *name;
@property (assign, nonatomic) CGFloat height;
@property (assign, nonatomic) NSInteger num;
@end
```

use the User model where you need

```
//create a new model
User *user = [[User alloc]init];
user.name = @"mason";
user.height = 180.23;
user.num = 123456;
[user saveModel]; 

NSLog(@"users count: %ld",User.allModels.count);

//find model
user = [User firstModelWhere:@{DBRowId: @(1)}];
NSLog(@"name %@,num: %ld,height: %lf",user.name,user.num,user.height);


//update model
[user updateModel:@{@"name": @"Dear"}];


user = [User firstModelWhere:@{DBRowId: @(1)}];
NSLog(@"name %@,num: %ld,height: %lf",user.name,user.num,user.height);

//delete model
[user deleteModel];
NSLog(@"users count: %ld",User.allModels.count);

```

#### More Interfaces

##### Configs

```
//dbPath
+(NSString*)dbPath;

//tableName,default is the current class
+(NSString*)tableName;

//primarykeys,default is DBRowID
+(NSArray*)primaryKeys;

//only properties to map table columns
+(NSArray *)onlyPropertiesToMapColumns;

//except properties to map table columns
+(NSArray *)exceptPropertiesToMapColumns;

//property to  column Mappings
+(NSDictionary *)propertyToColumnMappings;

//properties default values
+(NSDictionary *)defaultValues;

//properties value check values
+(NSDictionary *)checkValues;

//properties value length
+(NSDictionary *)lengthValues;

//properties value those should be unique
+(NSArray *)uniqueValues;

//properties value those should be not null
+(NSArray *)notNullValues;

+(NSString *)dateFormatterString;

+(NSString *)imagePathForImage:(NSString *)imgName ;

+(NSString *)dataPathForData:(NSString *)dataName;

//default is YES
+(BOOL)shouldMapAllParentPropertiesToTable;

//default is YES
+(BOOL)shouldMapAllSelfPropertiesToTable;

```

##### Create/Drop table

```
+(BOOL)createTable;

+(BOOL)dropTable;
```

##### Insert

```
+(BOOL)insertModel:(NSObject *)model;

+(BOOL)insertModelIfNotExists:(NSObject *)model;

-(BOOL)saveModel;
```

##### Update

```
+(BOOL)updateModelsWithModel:(NSObject *)model where:(NSObject *)where;

+(BOOL)updateModelsWithDictionary:(NSDictionary *)dic where:(NSObject *)where;

-(BOOL)updateModel:(id)value;
```

##### Find

```
+(BOOL)modelExists:(NSObject *)model;

+(NSArray *)allModels;

+(NSArray *)findModelsBySQL:(NSString *)sql;

+(NSArray *)findModelsWhere:(NSObject *)where;

+(NSArray *)findModelsWhere:(NSObject *)where orderBy:(NSString *)orderBy;

+(NSArray )findModelsWhere:(NSObject *)where groupBy:(NSString *)groupBy orderBy:(NSString)orderBy limit:(int)limit offset:(int)offset;

+(id)firstModelWhere:(NSObject *)where;

+(id)firstModelWhere:(NSObject )where orderBy:(NSString)orderBy ;

+(id)lastModel;

+(NSInteger)rowCountWhere:(NSObject *)where;
```

##### Delete

```
+(BOOL)deleteModel:(NSObject *)model;

+(BOOL)deleteModelsWhere:(NSObject *)where;

-(BOOL)deleteModel;
```

##### Transaction

```
+(void)beginTransaction;

+(void)commit;

+(void)rollback;
```



