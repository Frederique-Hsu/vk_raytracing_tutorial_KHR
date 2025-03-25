/*!
 *  \file       finalize.cpp
 *  \brief      
 *  
 */


#include "finalize.hpp"


template<typename FnReturnType>
class FinalAction
{
public:
    FinalAction(FnReturnType lambda_fn);
    ~FinalAction();
private:
    FnReturnType fn;
};

template<typename FnReturnType>
FinalAction<FnReturnType>::FinalAction(FnReturnType lambda_fn) : fn{lambda_fn}
{
}

template<typename FnReturnType>
FinalAction<FnReturnType>::~FinalAction()
{
    fn();
}

template<typename FnReturnType> 
FinalAction<FnReturnType> finalize(FnReturnType lambda_fn)
{
    return FinalAction<FnReturnType>(lambda_fn);
}