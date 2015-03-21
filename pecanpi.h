
#pragma pack(push)
#pragma pack(1)
typedef struct {
    int data_packet_bytes;
    int num_samples; // bytes=nchan*nsamples*size(sample_type)*ii_cmplx;
    int frame_num; // for dropped packet detection
    float fs; // sample rate of this packet
    float frame_time; // seconds since stream start. Ref to start of frame
    float f_bb; // 0=> real data, otherwise interleave complex part.
    char nchan; // channels are interleaved: first sample of all channels are adjacent.
    char sample_type; // 1=float32, 2=float64, 2=int16, 3=int32, 4=int64
    char packet_type; // 1=time-series, 2=frequencies, 3=freqSNR, 4=freqNORM
    char reserved[5];
} pecanpi_audio_hdr;
#pragma pack(pop)
    
