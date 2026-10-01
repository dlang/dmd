// Minified from <aws/s3/s3_client.h>

struct MyFoo {
};

typedef struct MyFoo *(MyFuncPtr)(struct MyFoo *allocator);

struct BrokenStruct {
    const struct MyFoo *network_interface_names_array;
    int num_network_interface_names;
    MyFuncPtr *buffer_pool_factory_fn;
    void *buffer_pool_user_data;
};
