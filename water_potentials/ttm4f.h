// Copyright 2013 Volodymyr Babin <vb27606@gmail.com>
//
// This is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// The code is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You can find a copy of the GNU General Public License at
// http://www.gnu.org/licenses/.

#ifndef TTM4F_H
#define TTM4F_H

#include <cstddef>
#include "electrostatics.h"

////////////////////////////////////////////////////////////////////////////////

namespace h2o {

//----------------------------------------------------------------------------//

struct ttm4f {

    ttm4f();
    ~ttm4f();

    const char* name() const
    {
        return "TTM4-F";
    }

    // crd is O H H O H H ... O H H
    double operator()(size_t nw, const double* crd, double* grd = 0);

private:
    void allocate(size_t);

    size_t  m_nw;
    double* m_memory;

private:
    ttm::electrostatics m_electrostatics;
    ttm::electrostatics::excluded_set_type m_excluded;

private: // non-copyable
    ttm4f(const ttm4f&);
    ttm4f& operator=(const ttm4f&);
};

//----------------------------------------------------------------------------//

} // namespace h2o

////////////////////////////////////////////////////////////////////////////////

#endif // TTM4F_H
