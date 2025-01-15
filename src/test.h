struct lfs_config {
    void *context;
    int block_cycles;
    
    int (*read)(const struct lfs_config *c, int block,
            int off, void *buffer, int size);
};