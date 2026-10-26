package com.ethioclicks.ethioPromo.bussinesLogic.entity;

import com.ethioclicks.ethioPromo.security.enums.AccountTypeEnum;
import jakarta.persistence.*;
import lombok.*;

import java.util.List;

@Entity
@Data
@AllArgsConstructor
@NoArgsConstructor
@Table(name = "INFLUENCER_ACCOUNT")
public class InfluencerAccount {
    @Id
    @GeneratedValue(strategy=GenerationType.IDENTITY)
    @Column(name = "ID")
    private Long id;
    @Column(name = "ACCOUNT_PUBLIC_ID")
    String accountPublicId;
    @Column(name = "TITLE")
    private String title;
    @Column(name = "DESCRIPTION", columnDefinition = "TEXT")
    private String description;
    @Column(name = "ACCOUNT_URL")
    private String accountURL;
    @Column(name = "IMAGE_URL")
    private String imageURL;
    @Column(name = "ACCOUNT_TYPE")
    private AccountTypeEnum accountType;
    // Preserve the original enum column for existing channels and older clients.
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "PLATFORM_CODE")
    private ChannelPlatform platform;
    @Transient
    @com.fasterxml.jackson.annotation.JsonProperty(access = com.fasterxml.jackson.annotation.JsonProperty.Access.WRITE_ONLY)
    private String platformCode;
    @Column(name = "AUDIENCE_COUNT")
    private long audienceCount;
    @Column(name = "MIN_VIEW_PER_POST_COUNT")
    private long minViewPerPostCount;
    @Column(name = "MAX_VIEW_PER_POST_COUNT")
    private long maxViewPerPostCount;
    @OneToMany(cascade = CascadeType.ALL)
    @JoinColumn(name = "TOP_VIEW_COUNT_ID")
    private List<TopViewCount> topViews;
    @OneToMany(cascade = CascadeType.ALL)
    @JoinColumn(name = "RECENT_VIEW_COUNT_ID")
    private List<RecentViewCount> recentViewCounts;
    @OneToMany(cascade = CascadeType.ALL)
    @JoinColumn(name = "PRICE_OPTIONS_ID")
    private List<PriceOptions> priceOptions;
    @Column(name = "IS_APPROVED")
    private Boolean approved = false;
    @Column(name = "IS_VERIFIED")
    private Boolean verified = false;
    @Column(name = "IS_DELETED")
    private Boolean deleted = false;
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "ACCOUNT_CATEGORY_ID", nullable = false)
    private AccountCategory category;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "USER_ID", nullable = false)
    @com.fasterxml.jackson.annotation.JsonIgnore
    private com.ethioclicks.ethioPromo.security.entity.User owner;







}
