/**
 * The main class which implements Data Matrix Code decoding -- as opposed to locating and extracting
 * the Data Matrix Code from an image.
 */

@class ZXBitMatrix, ZXDecoderResult, ZXReedSolomonDecoder;

@interface ZXDataMatrixDecoder : NSObject

- (ZXDecoderResult *)decode:(BOOL**)image length:(unsigned int)length error:(NSError**)error;
- (ZXDecoderResult *)decodeMatrix:(ZXBitMatrix *)bits error:(NSError**)error;

@end
