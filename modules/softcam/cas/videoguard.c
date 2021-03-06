/*
 * Astra Module: SoftCAM
 * http://cesbo.com/astra
 *
 * Copyright (C) 2012-2013, Andrey Dyldin <and@cesbo.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "../module_cam.h"

struct module_data_t
{
    MODULE_CAS_DATA();
};

static bool cas_check_em(module_data_t *mod, mpegts_psi_t *em)
{
    const uint8_t em_type = em->buffer[0];
    switch(em_type)
    {
        // ECM
        case 0x80:
        case 0x81:
        {
            return true;
        }
        default:
        {
            const uint8_t emm_type = (em->buffer[3] & 0xC0) >> 6;
            if(emm_type == 0)
            { // global
                return true;
            }
            else if(emm_type == 1 || emm_type == 2)
            {
                const uint8_t serial_count = ((em->buffer[3] >> 4) & 3) + 1;
                const uint8_t serial_len = (em->buffer[3] & 0x80) ? 3: 4;
                for(uint8_t i = 0; i < serial_count; ++i)
                {
                    const uint8_t *serial = &em->buffer[i * 4 + 4];
                    if(!memcmp(serial, &mod->__cas.decrypt->cam->ua[4], serial_len))
                        return true;
                }
            }
            break;
        }
    }

    return false;
}

static bool cas_check_keys(module_data_t *mod, const uint8_t *keys)
{
    __uarg(mod);
    __uarg(keys);
    return true;
}

/*
 * CA descriptor (iso13818-1):
 * tag      :8 (must be 0x09)
 * length   :8
 * caid     :16
 * reserved :3
 * pid      :13
 * data     :length-4
 */

static bool cas_check_descriptor(module_data_t *mod, const uint8_t *desc)
{
    __uarg(mod);
    __uarg(desc);
    return true;
}

static bool cas_check_caid(uint16_t caid)
{
    return ((caid & 0xFF00) == 0x0900);
}

MODULE_CAS(videoguard)
