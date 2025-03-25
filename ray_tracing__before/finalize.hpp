/*!
 *  \file       finalize.hpp
 *  \brief      
 *  
 */


#pragma once


template<typename FnReturnType> class FinalAction;

template<typename FnReturnType> FinalAction<FnReturnType> finalize(FnReturnType lambda_fn);