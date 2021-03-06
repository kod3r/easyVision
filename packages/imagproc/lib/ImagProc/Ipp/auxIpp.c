#include <ipp.h>
#include<stdlib.h>
#include<stdio.h>

#if IPP_VERSION_MAJOR > 7 || (IPP_VERSION_MAJOR == 7 && IPP_VERSION_MINOR >=1)
#define IPP71
#endif

#define hauxWarpPerspective(M) \
int auxWarpPerspective##M(void * pSrc, int sstep, int sh, int sw,       \
                               int sr1, int sr2, int sc1, int sc2,      \
                               void * pDst, int dstep,                  \
                               int dr1, int dr2, int dc1, int dc2,      \
                               const double *h, int interp)

#define auxWarpPerspective(M) \
hauxWarpPerspective(M)                                                  \
{                                                                       \
    IppiSize srcSize = {sw,sh};                                         \
    IppiRect srcRoi = {sc1,sr1,sc2-sc1+1,sr2-sr1+1};                    \
    IppiRect dstRoi = {dc1,dr1,dc2-dc1+1,dr2-dr1+1};                    \
    const double coeff [3][3] = {{h[0],h[1],h[2]},                      \
                                 {h[3],h[4],h[5]},                      \
                                 {h[6],h[7],h[8]}};                     \
    return ippiWarpPerspective##M(pSrc,srcSize,sstep,srcRoi,pDst,dstep,dstRoi,coeff,interp); \
}

// TO DO: add roi offset in pSrc & pDst
auxWarpPerspective(_32f_C1R)
auxWarpPerspective(_8u_C1R)
auxWarpPerspective(_8u_C3R)


// TO DO: reuse buffers
int auxResize_32f_C1R(void * pSrc, int sstep, int sh, int sw,
                      int sr1, int sr2, int sc1, int sc2,
                      void * pDst, int dstep,
                      int dr1, int dr2, int dc1, int dc2,
                      int interp)
{
    IppiSize srcSize = {sw,sh};
    IppiRect srcRoi = {sc1,sr1,sc2-sc1+1,sr2-sr1+1};
    IppiSize dstRoi = {dc2-dc1+1,dr2-dr1+1};
    double xf = (double)(dc2-dc1+1)/(sc2-sc1+1);
    double yf = (double)(dr2-dr1+1)/(sr2-sr1+1);

#ifdef IPP71
     
    if (interp != ippLinear) printf("sorry, using linear resize\n");

    int specSize, initSize, bufSize, numLobes=2, nChannel=1;
    IppiSize srcSizeR = {sc2-sc1+1,sr2-sr1+1};
    IppiPoint dstOffset = {0,0};
    // get working buffer sizes
    ippiResizeGetSize_32f(srcSizeR,dstRoi,ippLinear, 0, &specSize, &initSize);

    // allocate working buffers
    //Ipp8u *pInitBuf=ippsMalloc_8u(initSize);
    IppiResizeSpec_32f* pSpec=(IppiResizeSpec_32f*)ippsMalloc_8u(specSize);

    ippiResizeLinearInit_32f(srcSizeR, dstRoi, pSpec);

    ippiResizeGetBufferSize_8u(pSpec,dstRoi,nChannel,&bufSize);
    Ipp8u* pBuffer=ippsMalloc_8u(bufSize);

    int r = ippiResizeLinear_32f_C1R(pSrc+sstep*sr1+sc1*sizeof(float), sstep,
                                     pDst, dstep,
                                     dstOffset, dstRoi,
                                     ippBorderRepl, 0,
                                     pSpec, pBuffer);

    //ippsFree(pInitBuf);
    ippsFree(pSpec);
    ippsFree(pBuffer);

    return r;

#else

    return ippiResize_32f_C1R(pSrc,srcSize,sstep,srcRoi,pDst,dstep,dstRoi,xf,yf,interp);

#endif

}

int auxResize_8u_C1R(void * pSrc, int sstep, int sh, int sw,
                      int sr1, int sr2, int sc1, int sc2,
                      void * pDst, int dstep,
                      int dr1, int dr2, int dc1, int dc2,
                      int interp)
{
    IppiSize srcSize = {sw,sh};
    IppiRect srcRoi = {sc1,sr1,sc2-sc1+1,sr2-sr1+1};
    IppiSize dstRoi = {dc2-dc1+1,dr2-dr1+1};
    double xf = (double)(dc2-dc1+1)/(sc2-sc1+1);
    double yf = (double)(dr2-dr1+1)/(sr2-sr1+1);

#ifdef IPP71

    if (interp != ippLinear) printf("sorry, using linear resize\n");

    int specSize, initSize, bufSize, numLobes=2, nChannel=1;
    IppiSize srcSizeR = {sc2-sc1+1,sr2-sr1+1};
    IppiPoint dstOffset = {0,0};
    // get working buffer sizes
    ippiResizeGetSize_8u(srcSizeR,dstRoi,ippLinear, 0, &specSize, &initSize);

    // allocate working buffers
    //Ipp8u *pInitBuf=ippsMalloc_8u(initSize);
    IppiResizeSpec_32f* pSpec=(IppiResizeSpec_32f*)ippsMalloc_8u(specSize);

    ippiResizeLinearInit_8u(srcSizeR, dstRoi, pSpec);

    ippiResizeGetBufferSize_8u(pSpec,dstRoi,nChannel,&bufSize);
    Ipp8u* pBuffer=ippsMalloc_8u(bufSize);

    int r = ippiResizeLinear_8u_C1R(pSrc+sstep*sr1+sc1, sstep,
                                    pDst, dstep,
                                    dstOffset, dstRoi,
                                    ippBorderRepl, 0,
                                    pSpec, pBuffer);

    //ippsFree(pInitBuf);
    ippsFree(pSpec);
    ippsFree(pBuffer);

    return r;

#else

    return ippiResize_8u_C1R(pSrc,srcSize,sstep,srcRoi,pDst,dstep,dstRoi,xf,yf,interp);

#endif

}

int auxResize_8u_C3R(void * pSrc, int sstep, int sh, int sw,
                      int sr1, int sr2, int sc1, int sc2,
                      void * pDst, int dstep,
                      int dr1, int dr2, int dc1, int dc2,
                      int interp)
{
    IppiSize srcSize = {sw,sh};
    IppiRect srcRoi = {sc1,sr1,sc2-sc1+1,sr2-sr1+1};
    IppiSize dstRoi = {dc2-dc1+1,dr2-dr1+1};
    double xf = (double)(dc2-dc1+1)/(sc2-sc1+1);
    double yf = (double)(dr2-dr1+1)/(sr2-sr1+1);
    
#ifdef IPP71
    
    if (interp != ippLinear) printf("sorry, using linear resize\n");

    int specSize, initSize, bufSize, numLobes=2, nChannel=3;
    IppiSize srcSizeR = {sc2-sc1+1,sr2-sr1+1};
    IppiPoint dstOffset = {0,0};
    // get working buffer sizes
    ippiResizeGetSize_8u(srcSizeR,dstRoi,ippLinear, 0, &specSize, &initSize);

    // allocate working buffers
    //Ipp8u *pInitBuf=ippsMalloc_8u(initSize);
    IppiResizeSpec_32f* pSpec=(IppiResizeSpec_32f*)ippsMalloc_8u(specSize);

    ippiResizeLinearInit_8u(srcSizeR, dstRoi, pSpec);

    ippiResizeGetBufferSize_8u(pSpec,dstRoi,nChannel,&bufSize);
    Ipp8u* pBuffer=ippsMalloc_8u(bufSize);

    int r = ippiResizeLinear_8u_C3R(pSrc+sstep*sr1+sc1*3, sstep,
                                    pDst, dstep,
                                    dstOffset, dstRoi,
                                    ippBorderRepl, 0,
                                    pSpec, pBuffer);

    //ippsFree(pInitBuf);
    ippsFree(pSpec);
    ippsFree(pBuffer);

    return r;

#else

    return ippiResize_8u_C3R(pSrc,srcSize,sstep,srcRoi,pDst,dstep,dstRoi,xf,yf,interp);

#endif

}

//---------------- Discrete Cosine Transform ------------------

int auxDCTFwd_32f_C1R(float * pSrc, int sstep,
                      int sr1, int sr2, int sc1, int sc2,
                      float * pDst, int dstep,
                      int dr1, int dr2, int dc1, int dc2)
{
    int res;
    IppiSize roiSize = {dc2-dc1+1,dr2-dr1+1};
    IppiDCTFwdSpec_32f* context;
    res = ippiDCTFwdInitAlloc_32f (&context, roiSize, ippAlgHintFast);
    res = ippiDCTFwd_32f_C1R(pSrc+sr1*sstep/4+sc1,sstep,pDst+dr1*dstep/4+dc1,dstep,context,NULL);
    ippiDCTFwdFree_32f(context);
    return res;
}

int auxDCTInv_32f_C1R(float * pSrc, int sstep,
                      int sr1, int sr2, int sc1, int sc2,
                      float * pDst, int dstep,
                      int dr1, int dr2, int dc1, int dc2)
{
    int res;
    IppiSize roiSize = {dc2-dc1+1,dr2-dr1+1};
    IppiDCTInvSpec_32f* context;
    res = ippiDCTInvInitAlloc_32f (&context, roiSize, ippAlgHintFast);
    res = ippiDCTInv_32f_C1R(pSrc+sr1*sstep/4+sc1,sstep,pDst+dr1*dstep/4+dc1,dstep,context,NULL);
    ippiDCTInvFree_32f(context);
    return res;
}

//---------------- Image Inpainting ------------------

int auxInpainting_8u_C1R(float rad,     int method,
                         void  * pSrc,  int sstep,
                         void  * pMask, int mstep,
                         float * pDist, int distStep,
                         void  * pDst,  int dstep,
                         int dr1, int dr2, int dc1, int dc2)
{
    int res;
    IppiSize roiSize = {dc2-dc1+1,dr2-dr1+1};
    IppiInpaintState_8u_C1R* pState;
    int cmethod = method==0 ? IPP_INPAINT_TELEA : IPP_INPAINT_NS;
    res = ippiInpaintInitAlloc_8u_C1R(&pState, pDist, distStep, pMask, mstep, roiSize, rad, cmethod);
    //printf("alloc %d\n",res);
    res = ippiInpaint_8u_C1R(pSrc, sstep, pDst, dstep, roiSize, pState);
    //printf("inpaint %d\n",res);
    res = ippiInpaintFree_8u_C1R(pState);
    //printf("free %d\n",res);
    return res;
}
