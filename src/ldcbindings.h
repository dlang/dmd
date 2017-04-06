//===-- ldcbindings.h -----------------------------------------------------===//
//
//                         LDC – the LLVM D compiler
//
// This file is distributed under the BSD-style LDC license. See the LICENSE
// file for details.
//
//===----------------------------------------------------------------------===//

#ifndef LDC_DDMD_LDCBINDINGS_H
#define LDC_DDMD_LDCBINDINGS_H

#include "expression.h"
#include <cstdint>

using uint = uint32_t;

// Classes
IntegerExp *createIntegerExp(Loc loc, dinteger_t value, Type *type);
IntegerExp *createIntegerExp(dinteger_t value);
EqualExp *createEqualExp(TOK, Loc, Expression *, Expression *);
CmpExp *createCmpExp(TOK, Loc, Expression *, Expression *);
ShlExp *createShlExp(Loc, Expression *, Expression *);
ShrExp *createShrExp(Loc, Expression *, Expression *);
UshrExp *createUshrExp(Loc, Expression *, Expression *);
AndAndExp *createAndAndExp(Loc, Expression *, Expression *);
OrOrExp *createOrOrExp(Loc, Expression *, Expression *);
OrExp *createOrExp(Loc, Expression *, Expression *);
AndExp *createAndExp(Loc, Expression *, Expression *);
XorExp *createXorExp(Loc, Expression *, Expression *);
ModExp *createModExp(Loc, Expression *, Expression *);
MulExp *createMulExp(Loc, Expression *, Expression *);
DivExp *createDivExp(Loc, Expression *, Expression *);
AddExp *createAddExp(Loc, Expression *, Expression *);
MinExp *createMinExp(Loc, Expression *, Expression *);
RealExp *createRealExp(Loc, real_t, Type *);
NotExp *createNotExp(Loc, Expression *);
ComExp *createComExp(Loc, Expression *);
NegExp *createNegExp(Loc, Expression *);
AddrExp *createAddrExp(Loc, Expression *);
DsymbolExp *createDsymbolExp(Loc, Dsymbol *, bool = false);
Expression *createExpression(Loc loc, TOK op, int size);
TypeDelegate *createTypeDelegate(Type *t);
TypeIdentifier *createTypeIdentifier(Loc loc, Identifier *ident);

// Structs
//Loc createLoc(const char * filename, uint linnum, uint charnum);

/*
 * Define bindD<Type>::create(...) templated functions, to create D objects in templated code (class type is template parameter).
 * Used e.g. in toir.cpp
 */
template <class T> struct bindD {
  template <typename... Args> T *create(Args...) {
    assert(0 && "newD<> not implemented for this type");
  }
};
#define NEWD_TEMPLATE(T)                                                       \
  template <> struct bindD<T> {                                                \
    template <typename... Args> static T *create(Args... args) {               \
      return create##T(args...);                                               \
    }                                                                          \
  };
NEWD_TEMPLATE(ShlExp)
NEWD_TEMPLATE(ShrExp)
NEWD_TEMPLATE(UshrExp)
NEWD_TEMPLATE(AndAndExp)
NEWD_TEMPLATE(OrOrExp)
NEWD_TEMPLATE(OrExp)
NEWD_TEMPLATE(AndExp)
NEWD_TEMPLATE(XorExp)
NEWD_TEMPLATE(ModExp)
NEWD_TEMPLATE(MulExp)
NEWD_TEMPLATE(DivExp)
NEWD_TEMPLATE(AddExp)
NEWD_TEMPLATE(MinExp)

#endif // LDC_DDMD_LDCBINDINGS_H
