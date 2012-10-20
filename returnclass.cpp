#include <QApplication>
#include "returnclass.h"

int retval = 1;

void ReturnClass::confirmAgreement(int choice) {
    retval = choice;
    QApplication::exit();
}

