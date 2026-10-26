package com.ethioclicks.ethioPromo.bussinesLogic.entity;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "CHANNEL_PLATFORM")
@Data
public class ChannelPlatform {
    @Id
    @Column(name = "CODE", length = 50)
    private String code;
    @Column(name = "NAME", nullable = false, length = 100)
    private String name;
    @Column(name = "DISPLAY_ORDER", nullable = false)
    private Integer displayOrder = 0;
    @Column(name = "IS_DELETED", nullable = false)
    @com.fasterxml.jackson.annotation.JsonIgnore
    private boolean deleted;
}
