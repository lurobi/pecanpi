

void create_recorder(int samp_rate,char* dev_name,void **capture_handle_f);

void get_sample_buffer(void **capture_handle_f, short *buf,int nbuf);

void close_device(void **capture_handle);
