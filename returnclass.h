#ifndef RETURNCLASS_H
#define RETURNCLASS_H
#include <QObject>

extern int retval;

class ReturnClass : public QObject
{
    Q_OBJECT
public:
    Q_INVOKABLE void confirmAgreement(int choice);
};

#endif // RETURNCLASS_H

