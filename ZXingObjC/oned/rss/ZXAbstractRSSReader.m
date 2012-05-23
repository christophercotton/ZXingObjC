#import "ZXAbstractRSSReader.h"

static int MAX_AVG_VARIANCE;
static int MAX_INDIVIDUAL_VARIANCE;

float const MIN_FINDER_PATTERN_RATIO = 9.5f / 12.0f;
float const MAX_FINDER_PATTERN_RATIO = 12.5f / 14.0f;

const int RSS14_FINDER_PATTERNS_LEN = 9;
const int RSS14_FINDER_PATTERNS_SUB_LEN = 4;
const int RSS14_FINDER_PATTERNS[RSS14_FINDER_PATTERNS_LEN][RSS14_FINDER_PATTERNS_SUB_LEN] = {
  {3,8,2,1},
  {3,5,5,1},
  {3,3,7,1},
  {3,1,9,1},
  {2,7,4,1},
  {2,5,6,1},
  {2,3,8,1},
  {1,5,7,1},
  {1,3,9,1},
};

const int RSS_EXPANDED_FINDER_PATTERNS_LEN = 6;
const int RSS_EXPANDED_FINDER_PATTERNS_SUB_LEN = 4;
const int RSS_EXPANDED_FINDER_PATTERNS[RSS_EXPANDED_FINDER_PATTERNS_LEN][RSS_EXPANDED_FINDER_PATTERNS_SUB_LEN] = {
  {1,8,4,1}, // A
  {3,6,4,1}, // B
  {3,4,6,1}, // C
  {3,2,8,1}, // D
  {2,6,5,1}, // E
  {2,2,9,1}  // F
};

@interface ZXAbstractRSSReader ()

@property (nonatomic, assign) int * decodeFinderCounters;
@property (nonatomic, assign) unsigned int decodeFinderCountersLen;
@property (nonatomic, assign) int * dataCharacterCounters;
@property (nonatomic, assign) unsigned int dataCharacterCountersLen;
@property (nonatomic, assign) float * oddRoundingErrors;
@property (nonatomic, assign) unsigned int oddRoundingErrorsLen;
@property (nonatomic, assign) float * evenRoundingErrors;
@property (nonatomic, assign) unsigned int evenRoundingErrorsLen;
@property (nonatomic, assign) int * oddCounts;
@property (nonatomic, assign) unsigned int oddCountsLen;
@property (nonatomic, assign) int * evenCounts;
@property (nonatomic, assign) unsigned int evenCountsLen;

@end

@implementation ZXAbstractRSSReader

@synthesize decodeFinderCounters;
@synthesize decodeFinderCountersLen;
@synthesize dataCharacterCounters;
@synthesize dataCharacterCountersLen;
@synthesize oddRoundingErrors;
@synthesize oddRoundingErrorsLen;
@synthesize evenRoundingErrors;
@synthesize evenRoundingErrorsLen;
@synthesize oddCounts;
@synthesize oddCountsLen;
@synthesize evenCounts;
@synthesize evenCountsLen;

+ (void)initialize {
  MAX_AVG_VARIANCE = (int)(PATTERN_MATCH_RESULT_SCALE_FACTOR * 0.2f);
  MAX_INDIVIDUAL_VARIANCE = (int)(PATTERN_MATCH_RESULT_SCALE_FACTOR * 0.4f);
}

- (id)init {
  if (self = [super init]) {
    self.decodeFinderCountersLen = 4;
    self.decodeFinderCounters = (int*)malloc(self.decodeFinderCountersLen * sizeof(int));
    for (int i = 0; i < self.decodeFinderCountersLen; i++) {
      self.decodeFinderCounters[i] = 0;
    }

    self.dataCharacterCountersLen = 8;
    self.dataCharacterCounters = (int*)malloc(self.dataCharacterCountersLen * sizeof(int));
    for (int i = 0; i < self.dataCharacterCountersLen; i++) {
      self.dataCharacterCounters[i] = 0;
    }

    self.oddRoundingErrorsLen = 4;
    self.oddRoundingErrors = (float*)malloc(self.oddRoundingErrorsLen * sizeof(float));
    for (int i = 0; i < self.oddRoundingErrorsLen; i++) {
      self.oddRoundingErrors[i] = 0.0f;
    }

    self.evenRoundingErrorsLen = 4;
    self.evenRoundingErrors = (float*)malloc(self.evenRoundingErrorsLen * sizeof(float));
    for (int i = 0; i < self.evenRoundingErrorsLen; i++) {
      self.evenRoundingErrors[i] = 0.0f;
    }

    self.oddCountsLen = self.dataCharacterCountersLen / 2;
    self.evenCountsLen = self.dataCharacterCountersLen / 2;
    self.oddCounts = (int*)malloc(self.dataCharacterCountersLen / 2 * sizeof(int));
    self.evenCounts = (int*)malloc(self.dataCharacterCountersLen / 2 * sizeof(int));
    for (int i = 0; i < self.dataCharacterCountersLen / 2; i++) {
      self.oddCounts[i] = 0;
      self.evenCounts[i] = 0;
    }
  }

  return self;
}

- (void)dealloc {
  if (self.decodeFinderCounters != NULL) {
    free(self.decodeFinderCounters);
    self.decodeFinderCounters = NULL;
  }

  if (self.dataCharacterCounters != NULL) {
    free(self.dataCharacterCounters);
    self.dataCharacterCounters = NULL;
  }

  if (self.oddRoundingErrors != NULL) {
    free(self.oddRoundingErrors);
    self.oddRoundingErrors = NULL;
  }

  if (self.evenRoundingErrors != NULL) {
    free(self.evenRoundingErrors);
    self.evenRoundingErrors = NULL;
  }

  if (self.oddCounts != NULL) {
    free(self.oddCounts);
    self.oddCounts = NULL;
  }

  if (self.evenCounts != NULL) {
    free(self.evenCounts);
    self.evenCounts = NULL;
  }

  [super dealloc];
}

+ (int)parseFinderValue:(int*)counters countersSize:(unsigned int)countersSize finderPatternType:(RSS_PATTERNS)finderPatternType {
  switch (finderPatternType) {
    case RSS_PATTERNS_RSS14_PATTERNS:
      for (int value = 0; value < RSS14_FINDER_PATTERNS_LEN; value++) {
        if ([self patternMatchVariance:counters countersSize:countersSize pattern:(int*)RSS14_FINDER_PATTERNS[value] maxIndividualVariance:MAX_INDIVIDUAL_VARIANCE] < MAX_AVG_VARIANCE) {
          return value;
        }
      }
      break;

    case RSS_PATTERNS_RSS_EXPANDED_PATTERNS:
      for (int value = 0; value < RSS_EXPANDED_FINDER_PATTERNS_LEN; value++) {
        if ([self patternMatchVariance:counters countersSize:countersSize pattern:(int*)RSS_EXPANDED_FINDER_PATTERNS[value] maxIndividualVariance:MAX_INDIVIDUAL_VARIANCE] < MAX_AVG_VARIANCE) {
          return value;
        }
      }
      break;
      
    default:
      break;
  }

  return -1;
}

+ (int)count:(int*)array arrayLen:(unsigned int)arrayLen {
  int count = 0;

  for (int i = 0; i < arrayLen; i++) {
    count += array[i];
  }

  return count;
}

+ (void)increment:(int *)array arrayLen:(unsigned int)arrayLen errors:(float *)errors {
  int index = 0;
  float biggestError = errors[0];
  for (int i = 1; i < arrayLen; i++) {
    if (errors[i] > biggestError) {
      biggestError = errors[i];
      index = i;
    }
  }
  array[index]++;
}

+ (void)decrement:(int *)array arrayLen:(unsigned int)arrayLen errors:(float *)errors {
  int index = 0;
  float biggestError = errors[0];
  for (int i = 1; i < arrayLen; i++) {
    if (errors[i] < biggestError) {
      biggestError = errors[i];
      index = i;
    }
  }
  array[index]--;
}

+ (BOOL)isFinderPattern:(int*)counters countersLen:(unsigned int)countersLen {
  int firstTwoSum = counters[0] + counters[1];
  int sum = firstTwoSum + counters[2] + counters[3];
  float ratio = (float)firstTwoSum / (float)sum;
  if (ratio >= MIN_FINDER_PATTERN_RATIO && ratio <= MAX_FINDER_PATTERN_RATIO) {
    int minCounter = NSIntegerMax;
    int maxCounter = NSIntegerMin;
    for (int i = 0; i < countersLen; i++) {
      int counter = counters[i];
      if (counter > maxCounter) {
        maxCounter = counter;
      }
      if (counter < minCounter) {
        minCounter = counter;
      }
    }

    return maxCounter < 10 * minCounter;
  }
  return NO;
}

@end
