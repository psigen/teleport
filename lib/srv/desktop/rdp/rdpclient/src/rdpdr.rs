use byteorder::{LittleEndian, ReadBytesExt, WriteBytesExt};
use num_traits::{FromPrimitive, ToPrimitive};
use rdp::core::mcs;
use rdp::core::tpkt;
use rdp::model::data::Message;
use rdp::model::error::*;
use rdp::try_let;
use std::io::{Cursor, Read, Write};

type Payload = Cursor<Vec<u8>>;

pub struct Client {}

impl Client {
    pub fn new() -> Self {
        Client {}
    }
    pub fn read<S: Read + Write>(
        &mut self,
        payload: tpkt::Payload,
        mcs: &mut mcs::Client<S>,
    ) -> RdpResult<()> {
        let mut payload = try_let!(tpkt::Payload::Raw, payload)?;

        // Ignore this for now.
        let _pdu_header = ChannelPDUHeader::decode(&mut payload)?;

        let header = Header::decode(&mut payload)?;
        if let Component::RDPDR_CTYP_PRN = header.component {
            warn!("got {:?} RDPDR header from RDP server, ignoring because we're not redirecting any printers", header);
            return Ok(());
        }
        match header.packet_id {
            PacketId::PAKID_CORE_SERVER_ANNOUNCE => {
                let req = ServerAnnounceRequest::decode(&mut payload)?;
                info!("got {:?}", req);

                let resp = encode_message(
                    PacketId::PAKID_CORE_CLIENTID_CONFIRM,
                    &mut ClientAnnounceReply::new(req).encode()?,
                )?;
                info!("sending client announce reply");
                Ok(mcs.write(&"rdpdr".to_string(), resp)?)
            }
            PacketId::PAKID_CORE_SERVER_CAPABILITY => {
                let req = ServerCoreCapabilityRequest::decode(&mut payload)?;
                info!("got {:?}", req);

                let resp = encode_message(
                    PacketId::PAKID_CORE_CLIENT_CAPABILITY,
                    &mut ClientCoreCapabilityResponse::new_response().encode()?,
                )?;
                info!("sending client core capability response");
                Ok(mcs.write(&"rdpdr".to_string(), resp)?)
            }
            _ => {
                // TODO(awly): return an error here once the entire protocol is implemented?
                error!(
                    "RDPDR packets {:?} are not implemented yet, ignoring",
                    header.packet_id
                );
                Ok(())
            }
        }
    }
}

fn encode_message(packet_id: PacketId, payload: &mut Vec<u8>) -> RdpResult<Vec<u8>> {
    let mut inner = Header::new(Component::RDPDR_CTYP_CORE, packet_id).encode()?;
    inner.append(payload);
    let mut outer = ChannelPDUHeader::new(inner.length() as u32).encode()?;
    outer.append(&mut inner);
    Ok(outer)
}

fn invalid_data_error(msg: &str) -> Error {
    Error::RdpError(RdpError::new(RdpErrorKind::InvalidData, msg))
}

// ChannelPDUHeader flags.
const CHANNEL_FLAG_FIRST: u32 = 0x00000001;
const CHANNEL_FLAG_LAST: u32 = 0x00000002;

#[derive(Debug)]
struct ChannelPDUHeader {
    length: u32,
    flags: u32,
}

impl ChannelPDUHeader {
    fn new(length: u32) -> Self {
        Self {
            length,
            flags: CHANNEL_FLAG_FIRST | CHANNEL_FLAG_LAST,
        }
    }
    fn decode(payload: &mut Payload) -> RdpResult<Self> {
        Ok(Self {
            length: payload.read_u32::<LittleEndian>()?,
            flags: payload.read_u32::<LittleEndian>()?,
        })
    }
    fn encode(&self) -> RdpResult<Vec<u8>> {
        let mut w = vec![];
        w.write_u32::<LittleEndian>(self.length)?;
        w.write_u32::<LittleEndian>(self.flags)?;
        Ok(w)
    }
}

#[derive(Debug)]
struct Header {
    component: Component,
    packet_id: PacketId,
}

impl Header {
    fn new(component: Component, packet_id: PacketId) -> Self {
        Self {
            component,
            packet_id,
        }
    }
    fn decode(payload: &mut Payload) -> RdpResult<Self> {
        let component = payload.read_u16::<LittleEndian>()?;
        let packet_id = payload.read_u16::<LittleEndian>()?;
        Ok(Self {
            component: Component::from_u16(component).ok_or(invalid_data_error(&format!(
                "invalid component value {:#06x}",
                component
            )))?,
            packet_id: PacketId::from_u16(packet_id).ok_or(invalid_data_error(&format!(
                "invalid packet_id value {:#06x}",
                packet_id
            )))?,
        })
    }
    fn encode(&self) -> RdpResult<Vec<u8>> {
        let mut w = vec![];
        w.write_u16::<LittleEndian>(self.component.to_u16().unwrap())?;
        w.write_u16::<LittleEndian>(self.packet_id.to_u16().unwrap())?;
        Ok(w)
    }
}

#[derive(Debug, FromPrimitive, ToPrimitive)]
#[allow(non_camel_case_types)]
enum Component {
    RDPDR_CTYP_CORE = 0x4472,
    RDPDR_CTYP_PRN = 0x5052,
}

#[derive(Debug, FromPrimitive, ToPrimitive)]
#[allow(non_camel_case_types)]
enum PacketId {
    PAKID_CORE_SERVER_ANNOUNCE = 0x496E,
    PAKID_CORE_CLIENTID_CONFIRM = 0x4343,
    PAKID_CORE_CLIENT_NAME = 0x434E,
    PAKID_CORE_DEVICELIST_ANNOUNCE = 0x4441,
    PAKID_CORE_DEVICE_REPLY = 0x6472,
    PAKID_CORE_DEVICE_IOREQUEST = 0x4952,
    PAKID_CORE_DEVICE_IOCOMPLETION = 0x4943,
    PAKID_CORE_SERVER_CAPABILITY = 0x5350,
    PAKID_CORE_CLIENT_CAPABILITY = 0x4350,
    PAKID_CORE_DEVICELIST_REMOVE = 0x444D,
    PAKID_PRN_CACHE_DATA = 0x5043,
    PAKID_CORE_USER_LOGGEDON = 0x554C,
    PAKID_PRN_USING_XPS = 0x5543,
}

#[derive(Debug)]
struct ServerAnnounceRequest {
    version_major: u16,
    version_minor: u16,
    client_id: u32,
}

impl ServerAnnounceRequest {
    fn decode(payload: &mut Payload) -> RdpResult<Self> {
        Ok(Self {
            version_major: payload.read_u16::<LittleEndian>()?,
            version_minor: payload.read_u16::<LittleEndian>()?,
            client_id: payload.read_u32::<LittleEndian>()?,
        })
    }
}

const VERSION_MAJOR: u16 = 0x0001;
const VERSION_MINOR: u16 = 0x000c;

#[derive(Debug)]
struct ClientAnnounceReply {
    version_major: u16,
    version_minor: u16,
    client_id: u32,
}

impl ClientAnnounceReply {
    fn new(req: ServerAnnounceRequest) -> Self {
        Self {
            version_major: VERSION_MAJOR,
            version_minor: VERSION_MINOR,
            client_id: req.client_id,
        }
    }

    fn encode(&self) -> RdpResult<Vec<u8>> {
        let mut w = vec![];
        w.write_u16::<LittleEndian>(self.version_major)?;
        w.write_u16::<LittleEndian>(self.version_minor)?;
        w.write_u32::<LittleEndian>(self.client_id)?;
        Ok(w)
    }
}

#[derive(Debug)]
struct ServerCoreCapabilityRequest {
    num_capabilities: u16,
    padding: u16,
    capabilities: Vec<CapabilitySet>,
}

impl ServerCoreCapabilityRequest {
    fn new_response() -> Self {
        Self {
            num_capabilities: 2,
            padding: 0,
            capabilities: vec![
                CapabilitySet {
                    header: CapabilityHeader {
                        cap_type: CapabilityType::CAP_GENERAL_TYPE,
                        length: 8 + 36, // 8 byte header + 36 byte capability descriptor
                        version: GENERAL_CAPABILITY_VERSION_02,
                    },
                    data: Capability::General(GeneralCapabilitySet {
                        os_type: 0,
                        os_version: 0,
                        protocol_major_version: VERSION_MAJOR,
                        protocol_minor_version: VERSION_MINOR,
                        io_code_1: 0x00007fff, // Combination of all the required bits.
                        io_code_2: 0,
                        extended_pdu: 0x00000001 | 0x00000002, // RDPDR_DEVICE_REMOVE_PDUS | RDPDR_CLIENT_DISPLAY_NAME_PDU
                        extra_flags_1: 0,
                        extra_flags_2: 0,
                        special_type_device_cap: 1, // Request redirection of 1 special device - smartcard.
                    }),
                },
                CapabilitySet {
                    header: CapabilityHeader {
                        cap_type: CapabilityType::CAP_SMARTCARD_TYPE,
                        length: 8, // 8 byte header + empty capability descriptor
                        version: SMARTCARD_CAPABILITY_VERSION_01,
                    },
                    data: Capability::Smartcard,
                },
            ],
        }
    }

    fn encode(&self) -> RdpResult<Vec<u8>> {
        let mut w = vec![];
        w.write_u16::<LittleEndian>(self.num_capabilities)?;
        w.write_u16::<LittleEndian>(self.padding)?;
        for cap in self.capabilities.iter() {
            w.append(&mut cap.encode()?);
        }
        Ok(w)
    }

    fn decode(payload: &mut Payload) -> RdpResult<Self> {
        let num_capabilities = payload.read_u16::<LittleEndian>()?;
        let padding = payload.read_u16::<LittleEndian>()?;
        let mut capabilities = vec![];
        for _i in 0..num_capabilities {
            capabilities.push(CapabilitySet::decode(payload)?);
        }

        Ok(Self {
            num_capabilities,
            padding,
            capabilities,
        })
    }
}

#[derive(Debug)]
struct CapabilitySet {
    header: CapabilityHeader,
    data: Capability,
}

impl CapabilitySet {
    fn encode(&self) -> RdpResult<Vec<u8>> {
        let mut w = self.header.encode()?;
        w.append(&mut self.data.encode()?);
        Ok(w)
    }
    fn decode(payload: &mut Payload) -> RdpResult<Self> {
        let header = CapabilityHeader::decode(payload)?;
        let data = Capability::decode(payload, &header)?;

        Ok(Self { header, data })
    }
}

const SMARTCARD_CAPABILITY_VERSION_01: u32 = 0x00000001;
#[allow(dead_code)]
const GENERAL_CAPABILITY_VERSION_01: u32 = 0x00000001;
const GENERAL_CAPABILITY_VERSION_02: u32 = 0x00000002;

#[derive(Debug)]
struct CapabilityHeader {
    cap_type: CapabilityType,
    length: u16,
    version: u32,
}

impl CapabilityHeader {
    fn encode(&self) -> RdpResult<Vec<u8>> {
        let mut w = vec![];
        w.write_u16::<LittleEndian>(self.cap_type.to_u16().unwrap())?;
        w.write_u16::<LittleEndian>(self.length)?;
        w.write_u32::<LittleEndian>(self.version)?;
        Ok(w)
    }
    fn decode(payload: &mut Payload) -> RdpResult<Self> {
        let cap_type = payload.read_u16::<LittleEndian>()?;
        Ok(Self {
            cap_type: CapabilityType::from_u16(cap_type).ok_or(invalid_data_error(&format!(
                "invalid capability type {:#06x}",
                cap_type
            )))?,
            length: payload.read_u16::<LittleEndian>()?,
            version: payload.read_u32::<LittleEndian>()?,
        })
    }
}

#[derive(Debug, FromPrimitive, ToPrimitive)]
#[allow(non_camel_case_types)]
enum CapabilityType {
    CAP_GENERAL_TYPE = 0x0001,
    CAP_PRINTER_TYPE = 0x0002,
    CAP_PORT_TYPE = 0x0003,
    CAP_DRIVE_TYPE = 0x0004,
    CAP_SMARTCARD_TYPE = 0x0005,
}

#[derive(Debug)]
enum Capability {
    General(GeneralCapabilitySet),
    Printer,
    Port,
    Drive,
    Smartcard,
}

impl Capability {
    fn encode(&self) -> RdpResult<Vec<u8>> {
        match self {
            Capability::General(general) => Ok(general.encode()?),
            _ => Ok(vec![]),
        }
    }

    fn decode(payload: &mut Payload, header: &CapabilityHeader) -> RdpResult<Self> {
        match header.cap_type {
            CapabilityType::CAP_GENERAL_TYPE => Ok(Capability::General(
                GeneralCapabilitySet::decode(payload, header.version)?,
            )),
            CapabilityType::CAP_PRINTER_TYPE => Ok(Capability::Printer),
            CapabilityType::CAP_PORT_TYPE => Ok(Capability::Port),
            CapabilityType::CAP_DRIVE_TYPE => Ok(Capability::Drive),
            CapabilityType::CAP_SMARTCARD_TYPE => Ok(Capability::Smartcard),
        }
    }
}

#[derive(Debug)]
struct GeneralCapabilitySet {
    os_type: u32,
    os_version: u32,
    protocol_major_version: u16,
    protocol_minor_version: u16,
    io_code_1: u32,
    io_code_2: u32,
    extended_pdu: u32,
    extra_flags_1: u32,
    extra_flags_2: u32,
    special_type_device_cap: u32,
}

impl GeneralCapabilitySet {
    fn encode(&self) -> RdpResult<Vec<u8>> {
        let mut w = vec![];
        w.write_u32::<LittleEndian>(self.os_type)?;
        w.write_u32::<LittleEndian>(self.os_version)?;
        w.write_u16::<LittleEndian>(self.protocol_major_version)?;
        w.write_u16::<LittleEndian>(self.protocol_minor_version)?;
        w.write_u32::<LittleEndian>(self.io_code_1)?;
        w.write_u32::<LittleEndian>(self.io_code_2)?;
        w.write_u32::<LittleEndian>(self.extended_pdu)?;
        w.write_u32::<LittleEndian>(self.extra_flags_1)?;
        w.write_u32::<LittleEndian>(self.extra_flags_2)?;
        w.write_u32::<LittleEndian>(self.special_type_device_cap)?;
        Ok(w)
    }

    fn decode(payload: &mut Payload, version: u32) -> RdpResult<Self> {
        Ok(Self {
            os_type: payload.read_u32::<LittleEndian>()?,
            os_version: payload.read_u32::<LittleEndian>()?,
            protocol_major_version: payload.read_u16::<LittleEndian>()?,
            protocol_minor_version: payload.read_u16::<LittleEndian>()?,
            io_code_1: payload.read_u32::<LittleEndian>()?,
            io_code_2: payload.read_u32::<LittleEndian>()?,
            extended_pdu: payload.read_u32::<LittleEndian>()?,
            extra_flags_1: payload.read_u32::<LittleEndian>()?,
            extra_flags_2: payload.read_u32::<LittleEndian>()?,
            special_type_device_cap: if version == GENERAL_CAPABILITY_VERSION_02 {
                payload.read_u32::<LittleEndian>()?
            } else {
                0
            },
        })
    }
}

type ClientCoreCapabilityResponse = ServerCoreCapabilityRequest;
