#include "pdu.h"

uint64_t htonll_x(uint64_t x)
{
    return htonll(x);
//    union bswap_helper h;
//    h.i64 = x;
//    int32_t tmp = htonl(h.i32[1]);
//    h.i32[1] = htonl(h.i32[0]);
//    h.i32[0] = tmp;
//    return h.i64;
}

uint64_t ntohll_x(uint64_t x)
{
    return ntohll(x);
//    return htonll(x);
}


uint16_t htons_x(uint16_t x) {
    return htons(x);
}
uint16_t ntohs_x(uint16_t x){
    return ntohs(x);
}

uint32_t htonl_x(uint32_t x){
    return htonl(x);
}
uint32_t ntohl_x(uint32_t x){
    return ntohl(x);
}
