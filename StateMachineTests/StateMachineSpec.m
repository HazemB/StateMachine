#import "Kiwi.h"
#import <objc/runtime.h>
#import "LSStateMachine.h"

@interface Subscription : NSObject
@property (nonatomic, retain) NSString *state;
@end
void * statekey = &statekey;

@interface Subscription (State)
- (BOOL)activate;
- (BOOL)suspend;
- (BOOL)unsuspend;
- (BOOL)terminate;
@end
@implementation Subscription
+ (LSStateMachine *)stateMachine {
    LSStateMachine *sm = [[LSStateMachine alloc] init];
    [sm addState:@"pending"];
    [sm addState:@"active"];
    [sm addState:@"suspended"];
    [sm addState:@"terminated"];
    
    [sm when:@"activate" transitionFrom:@"pending" to:@"active"];
    [sm when:@"suspend" transitionFrom:@"active" to:@"suspended"];
    [sm when:@"unsuspend" transitionFrom:@"suspended" to:@"active"];
    [sm when:@"terminate" transitionFrom:@"active" to:@"terminated"];
    [sm when:@"terminate" transitionFrom:@"suspended" to:@"terminated"];
    
    return sm;
}

BOOL LSStateMachineTriggerEvent(id self, SEL _cmd) {
    NSString *currentState = [self performSelector:@selector(state)];
    LSStateMachine *sm = [[self class] performSelector:@selector(stateMachine)];
    NSString *nextState = [sm nextStateFrom:currentState forEvent:NSStringFromSelector(_cmd)];
    if (nextState) {
        [self performSelector:@selector(setState:) withObject:nextState];
        return YES;
    } else {
        return NO;
    }
}

+ (void) initialize {
    class_addMethod(self, @selector(activate), (IMP) LSStateMachineTriggerEvent, "i@:");
    class_addMethod(self, @selector(suspend), (IMP) LSStateMachineTriggerEvent, "i@:");
    class_addMethod(self, @selector(unsuspend), (IMP) LSStateMachineTriggerEvent, "i@:");
    class_addMethod(self, @selector(terminate), (IMP) LSStateMachineTriggerEvent, "i@:");

}
- (id)init {
    self = [super init];
    if (self) {
        _state = @"pending";
    }
    return self;
}

@end

SPEC_BEGIN(StateMachineSpec)
context(@"given a Subscripion", ^{
    __block Subscription *sut = nil;
    beforeEach(^{
        sut = [[Subscription alloc] init];
    });
    
    describe(@"default state", ^{
        it(@"should be 'pending'", ^{
            [[sut.state should] equal: @"pending"];
        });
    });
    
    describe(@"valid transitions", ^{
        describe(@"activate", ^{
            describe(@"from 'pending'", ^{
                it(@"should change the state to 'active'", ^{
                    [sut activate];
                    
                    [[sut.state should] equal:@"active"];
                });
                it(@"should return YES", ^{
                    [[theValue([sut activate]) should] beYes];
                });
            });
        });
        describe(@"suspend", ^{
            describe(@"from 'active'", ^{
                beforeEach(^{
                    [sut activate];
                });
                it(@"should change the state to 'suspended'", ^{
                    [sut suspend];
                    [[sut.state should] equal:@"suspended"];
                    
                });
                it(@"should return YES", ^{
                    [[theValue([sut suspend]) should] beYes];
                });
            });
        });
        describe(@"unsuspend", ^{
            describe(@"from 'suspended'", ^{
                beforeEach(^{
                    [sut activate];
                    [sut suspend];
                });
                it(@"should change the state to 'active'", ^{
                    [sut unsuspend];
                    [[sut.state should] equal:@"active"];
                });
                it(@"should return YES", ^{
                    [[theValue([sut unsuspend]) should] beYes];
                });
            });
        });
        describe(@"terminate", ^{
            describe(@"from'active'", ^{
                beforeEach(^{
                    [sut activate];
                });
                it(@"should change the state to 'terminated'", ^{
                    [sut terminate];
                    [[sut.state should] equal:@"terminated"];
                });
                it(@"should return YES", ^{
                    [[theValue([sut terminate]) should] beYes];
                });
            });
            describe(@"from 'suspended'", ^{
                beforeEach(^{
                    [sut activate];
                    [sut suspend];
                });
                it(@"should change the state to 'terminated'", ^{
                    [sut terminate];
                    [[sut.state should] equal:@"terminated"];
                });
                it(@"should return YES", ^{
                    [[theValue([sut terminate]) should] beYes];
                });
            });
        });
    });
    
    describe(@"invalid transitions", ^{
        describe(@"activate", ^{
            describe(@"from 'suspended", ^{
                beforeEach(^{
                    [sut activate];
                    [sut suspend];
                });
                it(@"should return NO", ^{
                    [[theValue([sut activate]) should] beNo];
                });
            });
        });
        describe(@"terminate", ^{
            describe(@"from pending", ^{
                it(@"should return NO", ^{
                    [[theValue([sut terminate]) should] beNo];
                });
            });
        });


    });
});
SPEC_END