module dmd.common.blake3;
// based on https://github.com/oconnor663/blake3_reference_impl_c/blob/main/reference_impl.c

@safe:
nothrow:
@nogc:

/**
 * Implementation of Blake 3 hash function with streaming disabled
 * meaning we hash the whole buffer at once.
 * Input is split into 1KB Chunks which could be hashed independently.
 * That said, in the compiler I expect almost all inputs will be 1 chunk.
 *
 * Chunks get split into 64B Blocks which get hashed and then mixed together
 *
 * Params:
 *     data = byte array to hash
 * Returns: Blake 3 hash of data
 **/
public ubyte[32] blake3(scope const ubyte[] data)
{
    ChunkState state;
    CVStack cvStack;
    size_t cursor = 0;

    //greater because if it's == we still need to finalize the last
    //chunk
    while (data.length - cursor > ChunkLength)
    {

        const ubyte[] chunk = data[cursor .. cursor + ChunkLength];
        updateChunkStateFull(state, chunk);

        //the chainingValue is now used to build up the merkle tree with other chunks
        addChunkToTree(cvStack, state.chainingValue, state.chunkCounter);

        //reset chunk, leaving chunkCounter  as is
        state.chainingValue = IV;
        state.block[] = 0;
        state.blocksCompressed = 0;

        cursor += ChunkLength;
    }

    //now handle the final chunk which might not be full

    //handle all but last block
    while (data.length - cursor > BlockLength)
    {
        uint[16] blockWords = bytesToWords(data[cursor .. cursor + BlockLength]);
        with(state)
        {
            //can't be end since we handle the last block separately below
            uint flag = blocksCompressed == 0 ? ChunkStartFlag : 0;
            uint[16] compressed = compress(chainingValue, blockWords, 64, //full block
                                           chunkCounter, flag);
            chainingValue = compressed[0 .. 8];
            blocksCompressed++;
        }
        cursor += BlockLength;
    }

    //handle last block, which could be the first block too
    uint flag = ChunkEndFlag | (state.blocksCompressed == 0 ? ChunkStartFlag : 0);

    //cast is safe bc this must be <= BlockLength
    const remainingBytes = cast(uint)(data.length - cursor);
    ubyte[BlockLength] lastBlock = 0;
    lastBlock[0 .. remainingBytes] = data[cursor .. $];

    uint[16] lastBlockWords = bytesToWords(lastBlock);

    uint[16] compressed = compress(state.chainingValue, lastBlockWords, remainingBytes,
                                   state.chunkCounter,
                                   flag | (state.chunkCounter == 0 ? RootFlag : 0));



    //merge all the remaining parent chunks in the tree
    uint[8] cv = compressed[0 .. 8];
    while (!cvStack.empty)
    {
        const leftSib = cvStack.pop();
        uint[16] blockWords;
        blockWords[0 .. 8] = leftSib[];
        blockWords[8 .. $] = cv[];
        cv[] = compress(IV, blockWords, 64, 0,
                        ParentFlag | (cvStack.empty ? RootFlag : 0))[0 .. 8];
    }

    //finally finalize the root chunk
    //convert words to bytes, little endian
    ubyte[32] ret;
    foreach (i, word; cv)
    {
        ret[i*4] = word & 0xFF;
        ret[i*4 + 1] = (word >> 8) & 0xFF;
        ret[i*4 + 2] = (word >> 16) & 0xFF;
        ret[i*4 + 3] = (word >> 24) & 0xFF;
    }
    return ret;
}

private:

const static uint[8] IV = [0x6a09e667 ,0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                           0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];

const static uint[16] permutation = [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8];

enum BlockLength = 64;
enum ChunkLength = 1024;
enum ChunkStartFlag = 1;
enum ChunkEndFlag = 2;
enum ParentFlag = 4;
enum RootFlag = 8;
enum HashLength = 32;


struct ChunkState
{
    //initialized for a non-keyed hash
    //todo reorder for alignment/caching?
    uint[8] chainingValue = IV;
    ulong chunkCounter = 0;
    ubyte[32] block = 0; //up to 32 bytes
    ubyte blocksCompressed = 0;

}

uint rotateRight(uint x, uint n)
{
    return (x >> n ) | ( x << (32 - n));
}


//round function
//a,b,c,d are elements of the state, m1, m2 are 2 words of the message
void g(ref uint a, ref uint b, ref uint c, ref uint d, uint m1, uint m2)
{
    a = a + b + m1;
    d = rotateRight(d ^ a, 16);
    c = c + d;
    b = rotateRight(b ^ c, 12);
    a = a + b + m2;
    d = rotateRight(d ^ a, 8);
    c = c + d;
    b = rotateRight(b ^ c, 7);
}

void roundFunction(ref uint[16]  state, const ref uint[16] message)
{
    //columns of 4x4 state matrix
    g(state[0], state[4], state[8], state[12], message[0], message[1]);
    g(state[1], state[5], state[9], state[13], message[2], message[3]);
    g(state[2], state[6], state[10], state[14], message[4], message[5]);
    g(state[3], state[7], state[11], state[15], message[6], message[7]);

    //diagonals
    g(state[0], state[5], state[10], state[15], message[8], message[9]);
    g(state[1], state[6], state[11], state[12], message[10], message[11]);
    g(state[2], state[7], state[8], state[13], message[12], message[13]);
    g(state[3], state[4], state[9], state[14], message[14], message[15]);
}

void permute(ref uint[16] block)
{
    uint[16] permuted;
    foreach (i; 0 .. 16)
    {
        permuted[i] = block[permutation[i]];
    }
    block = permuted;
}


//Note, for our implementation, I think only the first 8 words are ever used
uint[16] compress(const ref uint[8] chainingValue, const ref uint[16] blockWords,
                  uint blockLength, //in case the block isn't full
                  ulong chunkCounter, uint flags)
{


    uint[16] state;
    state[0 .. 8] = chainingValue[];
    state[8 .. 12] = IV[0 .. 4];
    state[12] = cast(uint)chunkCounter;
    state[13] = cast(uint)(chunkCounter >> 32);
    state[14] = blockLength;
    state[15] = flags;

    uint[16] block = blockWords;
    foreach (i; 0..6)
    {
        roundFunction(state, block);
        permute(block);
    }
    roundFunction(state, block); //skip permuation the last time

    foreach (i; 0 .. 8)
    {
        state[i] ^= state[i + 8];
        state[i + 8] ^= chainingValue[i];
    }

    return state;
}


//if block isn't full, only the first blockLength/4 words
//will be filled in
uint[16] bytesToWords(scope const ubyte[] block)
{
    uint[16] ret = 0;
    foreach(i; 0 .. (block.length/4))
    {
        ret[i] = block[4*i];
        ret[i] |= (cast(uint)block[4*i + 1]) << 8;
        ret[i] |= (cast(uint)block[4*i + 2]) << 16;
        ret[i] |= (cast(uint)block[4*i + 3]) << 24;
    }
    return ret;
}


//full sized chunks, so no need to check for partial blocks, etc
void updateChunkStateFull(ref ChunkState chunkState, scope const ubyte[] chunk)
{
    for (size_t cursor = 0; cursor < ChunkLength; cursor += BlockLength)
    {
        uint[16] blockWords = bytesToWords(chunk[cursor .. cursor + BlockLength]);

        with(chunkState)
        {
            //first block gets ChunkStart, last gets ChunkEnd
            uint flag = blocksCompressed == 0 ? ChunkStartFlag :
                (blocksCompressed == (ChunkLength/BlockLength -1) ? ChunkEndFlag : 0);

            uint[16] compressed = compress(chainingValue, blockWords,
                                           64, //full blocks
                                           chunkCounter,
                                           flag); //start flag

            //use the first 8 bytes of this
            chainingValue = compressed[0..8];
            blocksCompressed++;

        }
    }
    chunkState.chunkCounter++;
    //Need to handle one more block if this one is partial
}


struct CVStack
{
    uint[8][54] data; //enough space for a really deep tree
    uint size = 0;

    nothrow:
    @safe:
    @nogc:

    bool empty() const { return size == 0; }

    void push(uint[8] cv)
    {
        data[size] = cv;
        size++;
    }

    uint[8] pop()
    {
        return data[--size];
    }
}



void addChunkToTree(ref CVStack cvStack, uint[8] cv, ulong totalChunks)
{
    //if the total number of chunks ends in 0 bits, then this completed
    //a subtree, so we'll add as many parent nodes as we can up the tree

    //this method won't be called on the final chunk, so we never set the
    //ROOT flag
    while ( (totalChunks & 1) == 0)
    {
        const top = cvStack.pop();
        uint[16] blockWords;
        blockWords[0 .. 8] = top[];
        blockWords[8 .. $] = cv[];
        cv = compress(IV, blockWords, 64, 0, ParentFlag)[0 .. 8];
        totalChunks >>= 1;
    }
    cvStack.push(cv);
}



unittest {
    //test vectors from the spec.  Run it on inputs of
    //[0, 1, 2, ... 249, 250, 0, 1, 2, ...] of various lengths

    //available here:
    //https://github.com/oconnor663/blake3_reference_impl_c/blob/main/test_vectors.json

    ubyte[N] testVector(size_t N)()
    {
        ubyte[N] ret;
        foreach (i, ref x; ret)
        {
            x = i % 251;
        }
        return ret;
    }

    const oneByte = testVector!1;
    //todo use hex literals once DMD bootstrap version gets big enough
    static const expectedOneByte = [0x2d,0x3a,0xde,0xdf,0xf1,0x1b,0x61,0xf1,
                                    0x4c,0x88,0x6e,0x35,0xaf,0xa0,0x36,0x73,
                                    0x6d,0xcd,0x87,0xa7,0x4d,0x27,0xb5,0xc1,
                                    0x51,0x02,0x25,0xd0,0xf5,0x92,0xe2,0x13];
    assert(blake3(oneByte) == expectedOneByte);

    static const expectedTwoBlocks = [0xde,0x1e,0x5f,0xa0,0xbe,0x70,0xdf,0x6d,
                                      0x2b,0xe8,0xff,0xfd,0x0e,0x99,0xce,0xaa,
                                      0x8e,0xb6,0xe8,0xc9,0x3a,0x63,0xf2,0xd8,
                                      0xd1,0xc3,0x0e,0xcb,0x6b,0x26,0x3d,0xee];
    const twoBlockInput = testVector!65;
    assert(blake3(twoBlockInput) == expectedTwoBlocks);

    static const expectedOneChunk = [0x42,0x21,0x47,0x39,0xf0,0x95,0xa4,0x06,
                                     0xf3,0xfc,0x83,0xde,0xb8,0x89,0x74,0x4a,
                                     0xc0,0x0d,0xf8,0x31,0xc1,0x0d,0xaa,0x55,
                                     0x18,0x9b,0x5d,0x12,0x1c,0x85,0x5a,0xf7];
    const barelyOneChunk = testVector!1024;
    assert(blake3(barelyOneChunk) == expectedOneChunk);

    static const expectedTwoChunks = [0xd0,0x02,0x78,0xae,0x47,0xeb,0x27,0xb3,
                                      0x4f,0xae,0xcf,0x67,0xb4,0xfe,0x26,0x3f,
                                      0x82,0xd5,0x41,0x29,0x16,0xc1,0xff,0xd9,
                                      0x7c,0x8c,0xb7,0xfb,0x81,0x4b,0x84,0x44];
    const barelyTwoChunks = testVector!1025;
    assert(blake3(barelyTwoChunks) == expectedTwoChunks);

    static const expectedBig = [0x62,0xb6,0x96,0x0e,0x1a,0x44,0xbc,0xc1,
                                0xeb,0x1a,0x61,0x1a,0x8d,0x62,0x35,0xb6,
                                0xb4,0xb7,0x8f,0x32,0xe7,0xab,0xc4,0xfb,
                                0x4c,0x6c,0xdc,0xce,0x94,0x89,0x5c,0x47];
    const bigInput = testVector!31_744;
    assert(blake3(bigInput) == expectedBig);
}
